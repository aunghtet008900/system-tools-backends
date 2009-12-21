/* -*- Mode: C; c-file-style: "gnu"; tab-width: 8 -*- */
/* Copyright (C) 2006 Carlos Garnacho
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
 *
 * Authors: Carlos Garnacho Parro  <carlosg@gnome.org>,
 *          Milan Bouchet-Valat <nalimilan@club.fr>.
 */

#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <glib.h>
#include <glib-object.h>
#include <dbus/dbus.h>
#include <dbus/dbus-glib-lowlevel.h>
#include "config.h"
#include "dispatcher.h"

#ifdef HAVE_POLKIT
#include <polkit/polkit.h>
#endif

#ifdef HAVE_GIO
#include "file-monitor.h"
#endif

#define DBUS_ADDRESS_ENVVAR "DBUS_SESSION_BUS_ADDRESS"
#define DBUS_INTERFACE_STB "org.freedesktop.SystemToolsBackends"
#define DBUS_INTERFACE_STB_PLATFORM "org.freedesktop.SystemToolsBackends.Platform"
#define DBUS_PATH_SELF_CONFIG "/org/freedesktop/SystemToolsBackends/SelfConfig2"

#define STB_DISPATCHER_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), STB_TYPE_DISPATCHER, StbDispatcherPrivate))

#define DEBUG(d,m...) \
if (G_UNLIKELY (((StbDispatcherPrivate *) d->_priv)->debug)) \
  { \
    g_debug (m); \
  }

enum {
  PROP_0,
  PROP_DEBUG
};

typedef struct StbDispatcherPrivate   StbDispatcherPrivate;
typedef struct StbDispatcherAsyncData StbDispatcherAsyncData;

struct StbDispatcherPrivate
{
  DBusConnection *connection;
  gchar *platform;

#ifdef HAVE_POLKIT
  PolkitAuthority *polkit_authority;
#endif

#ifdef HAVE_GIO
  StbFileMonitor *file_monitor;
#endif

  guint debug : 1;
};

struct StbDispatcherAsyncData
{
  StbDispatcher *dispatcher;
  gchar *destination;
  gint serial;
};

static void     stb_dispatcher_class_init  (StbDispatcherClass    *class);
static void     stb_dispatcher_init        (StbDispatcher         *object);
static void     stb_dispatcher_finalize    (GObject               *object);

static GObject* stb_dispatcher_constructor (GType                  type,
					    guint                  n_construct_properties,
					    GObjectConstructParam *construct_params);

static void     stb_dispatcher_set_property (GObject      *object,
					     guint         prop_id,
					     const GValue *value,
					     GParamSpec   *pspec);
static void     stb_dispatcher_get_property (GObject      *object,
					     guint         prop_id,
					     GValue       *value,
					     GParamSpec   *pspec);

static gchar*   get_destination            (DBusMessage *message);


G_DEFINE_TYPE (StbDispatcher, stb_dispatcher, G_TYPE_OBJECT);

static void
stb_dispatcher_class_init (StbDispatcherClass *class)
{
  GObjectClass *object_class = G_OBJECT_CLASS (class);

  object_class->constructor = stb_dispatcher_constructor;
  object_class->set_property = stb_dispatcher_set_property;
  object_class->get_property = stb_dispatcher_get_property;
  object_class->finalize = stb_dispatcher_finalize;

  g_object_class_install_property (object_class,
				   PROP_DEBUG,
				   g_param_spec_boolean ("debug", "", "",
							 FALSE,
							 G_PARAM_READWRITE));
  g_type_class_add_private (object_class,
			    sizeof (StbDispatcherPrivate));
}

static void
async_data_free (StbDispatcherAsyncData *data)
{
  g_object_unref (data->dispatcher);
  g_free (data->destination);
  g_free (data);
}

static gchar *
retrieve_platform (DBusMessage *message)
{
      DBusMessageIter iter;
      const gchar *str;

      dbus_message_iter_init (message, &iter);
      dbus_message_iter_get_basic (&iter, &str);

      if (str && *str)
	return g_strdup (str);

      return NULL;
}

#ifdef HAVE_GIO
static void
dispatch_file_list (DBusPendingCall *pending_call,
		    gpointer         data)
{
  StbDispatcher *dispatcher;
  StbDispatcherPrivate *priv;
  DBusMessage *reply;
  DBusError error;
  gchar **files;
  gint n_files;

  dispatcher = STB_DISPATCHER (data);
  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  reply = dbus_pending_call_steal_reply (pending_call);
  dbus_error_init (&error);

  if (dbus_set_error_from_message (&error, reply))
    {
      g_critical ("%s", error.message);
      dbus_error_free (&error);
      dbus_message_unref (reply);
      return;
    }

  if (dbus_message_get_args (reply, &error,
			     DBUS_TYPE_ARRAY, DBUS_TYPE_STRING, &files, &n_files,
			     DBUS_TYPE_INVALID))
    {
      stb_file_monitor_add_files (priv->file_monitor,
				  dbus_message_get_path (reply),
				  (const gchar **) files);
      dbus_free_string_array (files);
    }
  else
    {
      g_critical ("%s", error.message);
    }

  dbus_message_unref (reply);
}

static void
query_file_list (StbDispatcher *dispatcher,
		 DBusMessage   *message)
{
  StbDispatcherPrivate *priv;
  DBusPendingCall *pending_call;
  DBusMessage *file_message;
  gchar *destination;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  destination = get_destination (message);

  if (G_UNLIKELY (!destination))
    return;

  if (stb_file_monitor_is_object_handled (priv->file_monitor, destination))
    {
      g_free (destination);
      return;
    }

  file_message = dbus_message_new_method_call (destination,
					       dbus_message_get_path (message),
					       DBUS_INTERFACE_STB,
					       "getFiles");

  dbus_connection_send_with_reply (priv->connection, file_message, &pending_call, -1);

  if (pending_call)
    {
      dbus_pending_call_set_notify (pending_call,
				    dispatch_file_list,
				    g_object_ref (dispatcher),
				    (DBusFreeFunction) g_object_unref);
      dbus_pending_call_unref (pending_call);
    }

  dbus_message_unref (file_message);
  g_free (destination);
}

static void
object_changed_cb (StbDispatcher *dispatcher,
		   const gchar   *object_path)
{
  StbDispatcherPrivate *priv;
  DBusMessage *signal;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  signal = dbus_message_new_signal (object_path, DBUS_INTERFACE_STB, "changed");

  dbus_connection_send (priv->connection, signal, NULL);
  dbus_message_unref (signal);
}
#endif /* HAVE_GIO */

static void
dispatch_reply (DBusPendingCall *pending_call,
		gpointer         data)
{
  StbDispatcherPrivate *priv;
  DBusMessage *reply;
  StbDispatcherAsyncData *async_data;
  DBusError error;

  reply = dbus_pending_call_steal_reply (pending_call);
  async_data = (StbDispatcherAsyncData *) data;
  priv = async_data->dispatcher->_priv;
  dbus_error_init (&error);

  DEBUG (async_data->dispatcher, "sending reply from: %s", dbus_message_get_path (reply));

  if (dbus_set_error_from_message (&error, reply))
    {
      g_warning ("%s", error.message);
      dbus_error_free (&error);
    }

  if (dbus_message_has_interface (reply, DBUS_INTERFACE_STB_PLATFORM) &&
      dbus_message_has_member (reply, "getPlatform") && !priv->platform)
    {
      /* get the platform if necessary */
      priv->platform = retrieve_platform (reply);
    }
#ifdef HAVE_GIO
  else if (dbus_message_has_interface (reply, DBUS_INTERFACE_STB))
    {
      /* monitor configuration files */
      query_file_list (async_data->dispatcher, reply);
    }
#endif /* HAVE_GIO */

  /* send the reply back */
  dbus_message_set_destination (reply, async_data->destination);
  dbus_message_set_reply_serial (reply, async_data->serial);
  dbus_connection_send (priv->connection, reply, NULL);

  dbus_message_unref (reply);
}

static gchar*
get_destination (DBusMessage *message)
{
  gchar **arr, *destination = NULL;

  if (!dbus_message_get_path_decomposed (message, &arr))
    return NULL;

  if (!arr)
    return NULL;

  /* paranoid check */
  if (arr[0] && strcmp (arr[0], "org") == 0 &&
      arr[1] && strcmp (arr[1], "freedesktop") == 0 &&
      arr[2] && strcmp (arr[2], "SystemToolsBackends") == 0 && arr[3] && !arr[4])
    destination = g_strdup_printf (DBUS_INTERFACE_STB ".%s", arr[3]);

  dbus_free_string_array (arr);

  return destination;
}

static gboolean
can_caller_do_action (StbDispatcher *dispatcher,
		      DBusMessage   *message,
		      const gchar   *name)
{
#ifdef HAVE_POLKIT
  StbDispatcherPrivate *priv;
  PolkitSubject *subject;
  PolkitAuthorizationResult *result;
  gchar *action_id;
  gulong caller_pid;
  gboolean retval;
  GError *gerror = NULL;
  DBusError dbus_error;
  DBusMessage *call, *reply;
  const gchar *connection_name;

  /* Allow getting information */
  if (dbus_message_has_member (message, "get"))
    return TRUE;

  /* Do not allow anything besides "set", "add" or "del" past this point */
  if (!(dbus_message_has_member (message, "set")
       || dbus_message_has_member (message, "add")
       || dbus_message_has_member (message, "del")))
    return FALSE;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);

  if (name)
    action_id = g_strdup_printf ("org.freedesktop.systemtoolsbackends.%s.set", name);
  else
    action_id = g_strdup_printf ("org.freedesktop.systemtoolsbackends.set");

  /* Get the caller's PID using the connection name */
  call = dbus_message_new_method_call ("org.freedesktop.DBus",
				       "/org/freedesktop/DBus",
				       "org.freedesktop.DBus",
				       "GetConnectionUnixProcessID");
  connection_name = dbus_message_get_sender (message);
  dbus_message_append_args (call, DBUS_TYPE_STRING, &connection_name, DBUS_TYPE_INVALID);

  dbus_error_init (&dbus_error);

  reply = dbus_connection_send_with_reply_and_block (priv->connection, call, -1, &dbus_error);
  if (dbus_error_is_set (&dbus_error))
    goto dbus_error;

  dbus_message_get_args (reply, &dbus_error, DBUS_TYPE_UINT32, &caller_pid, DBUS_TYPE_INVALID);
  if (dbus_error_is_set (&dbus_error))
    goto dbus_error;

  dbus_message_unref (call);
  dbus_message_unref (reply);

  /* We need to identify the subject using its PID
   * because it's how PolkitLockButton works on the client side */
  subject = polkit_unix_process_new (caller_pid);
  result = polkit_authority_check_authorization_sync (priv->polkit_authority, subject, action_id, NULL,
                                                      POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
                                                      NULL, &gerror);

  g_object_unref (subject);

  if (gerror)
    {
      g_critical ("%s", gerror->message);
      g_error_free (gerror);
      g_free (action_id);

      return FALSE;
    }

  retval = polkit_authorization_result_get_is_authorized (result);

  DEBUG (dispatcher,
	 (retval) ? "subject is allowed to do action '%s'" : "subject can't do action '%s'",
	 action_id);

  g_free (action_id);

  return retval;

  dbus_error:
    g_critical ("Could not get PID of the caller: %s", dbus_error.message);
    dbus_error_free (&dbus_error);
    g_free (action_id);

    return FALSE;
#else
  return TRUE;
#endif /* HAVE_POLKIT */
}

static void
dispatch_stb_message (StbDispatcher *dispatcher,
		      DBusMessage   *message,
		      gint           serial)
{
  StbDispatcherPrivate *priv;
  DBusMessage *copy;
  DBusPendingCall *pending_call;
  StbDispatcherAsyncData *async_data;
  gchar *destination;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  destination = get_destination (message);

  /* there's something wrong with the message */
  if (G_UNLIKELY (!destination))
    {
      g_critical ("Could not get a valid destination, original one was: %s", dbus_message_get_path (message));
      return;
    }

  DEBUG (dispatcher, "dispatching message to: %s", dbus_message_get_path (message));

  copy = dbus_message_copy (message);

  /* forward the message to the corresponding service */
  dbus_message_set_destination (copy, destination);
  dbus_connection_send_with_reply (priv->connection, copy, &pending_call, -1);

  if (pending_call)
    {
      async_data = g_new0 (StbDispatcherAsyncData, 1);
      async_data->dispatcher = g_object_ref (dispatcher);
      async_data->destination = g_strdup (dbus_message_get_sender (message));
      async_data->serial = (serial) ? serial : dbus_message_get_serial (message);

      dbus_pending_call_set_notify (pending_call, dispatch_reply, async_data, (DBusFreeFunction) async_data_free);
      dbus_pending_call_unref (pending_call);
    }

  g_free (destination);
  dbus_message_unref (copy);
}

static void
return_error (StbDispatcher *dispatcher,
	      DBusMessage   *message,
	      const gchar   *error_name)
{
  DBusMessage *reply;
  StbDispatcherPrivate *priv;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);

  DEBUG (dispatcher, "sending error %s from: %s", error_name, dbus_message_get_path (message));

  reply = dbus_message_new_error (message, error_name,
				  "No permissions to perform the task.");
  dbus_connection_send (priv->connection, reply, NULL);
  dbus_message_unref (reply);
}

static void
dispatch_platform_message (StbDispatcher *dispatcher,
			   DBusMessage   *message)
{
  StbDispatcherPrivate *priv;

  priv = dispatcher->_priv;

  if (!dbus_message_has_interface (message, DBUS_INTERFACE_STB_PLATFORM))
    return;

  if (dbus_message_has_member (message, "getPlatform") && priv->platform)
    {
      DBusMessage *reply;
      DBusMessageIter iter;

      /* create a reply with the stored platform */
      reply = dbus_message_new_method_return (message);
      dbus_message_iter_init_append (reply, &iter);
      dbus_message_iter_append_basic (&iter, DBUS_TYPE_STRING, &priv->platform);

      dbus_connection_send (priv->connection, reply, NULL);
      dbus_message_unref (reply);

      return;
    }
  else if (dbus_message_has_member (message, "setPlatform"))
    priv->platform = retrieve_platform (message);

  dispatch_stb_message (dispatcher, message, 0);
}

static void
dispatch_self_config (StbDispatcher *dispatcher,
		      DBusMessage   *message)
{
  StbDispatcherPrivate *priv;
  const gchar *sender;
  uid_t uid, message_uid;

  priv = dispatcher->_priv;
  sender = dbus_message_get_sender (message);
  uid = (uid_t) dbus_bus_get_unix_user (priv->connection, sender, NULL);

  g_return_if_fail (uid != -1);

  if (dbus_message_get_args (message, NULL,
                             DBUS_TYPE_UINT32, &message_uid,
                             DBUS_TYPE_INVALID)
                             && message_uid == uid)
    {
      dbus_message_set_sender (message, sender);
      dispatch_stb_message (dispatcher, message, dbus_message_get_serial (message));
      dbus_message_unref (message);
    }
  else
    return_error (dispatcher, message, DBUS_ERROR_ACCESS_DENIED);
}

static DBusHandlerResult
dispatcher_filter_func (DBusConnection *connection,
			DBusMessage    *message,
			void           *data)
{
  StbDispatcher *dispatcher = STB_DISPATCHER (data);

  if (dbus_message_is_signal (message, DBUS_INTERFACE_LOCAL, "Disconnected"))
    {
      /* FIXME: handle Disconnect */
    }
  else if (dbus_message_is_signal (message, DBUS_INTERFACE_DBUS, "NameOwnerChanged"))
    {
      /* FIXME: handle NameOwnerChanged */
    }
  else if (dbus_message_has_interface (message, DBUS_INTERFACE_INTROSPECTABLE))
    dispatch_stb_message (dispatcher, message, 0);
  else if (dbus_message_has_interface (message, DBUS_INTERFACE_STB_PLATFORM))
    dispatch_platform_message (dispatcher, message);
  else if (dbus_message_has_path (message, DBUS_PATH_SELF_CONFIG))
    {
      if (can_caller_do_action (dispatcher, message, "self"))
	dispatch_self_config (dispatcher, message);
      else
	return_error (dispatcher, message, DBUS_ERROR_ACCESS_DENIED);
    }
  else if (dbus_message_has_interface (message, DBUS_INTERFACE_STB))
    {
      if (can_caller_do_action (dispatcher, message, NULL))
	dispatch_stb_message (dispatcher, message, 0);
      else
	return_error (dispatcher, message, DBUS_ERROR_ACCESS_DENIED);
    }

  return DBUS_HANDLER_RESULT_HANDLED;
}

static void
setup_connection (StbDispatcher *dispatcher)
{
  StbDispatcherPrivate *priv;
  DBusError error;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  dbus_error_init (&error);

  priv->connection = dbus_bus_get (DBUS_BUS_SYSTEM, &error);

  if (dbus_error_is_set (&error))
    {
      g_critical ("%s", error.message);
      dbus_error_free (&error);
    }

  dbus_connection_set_exit_on_disconnect (priv->connection, FALSE);
  dbus_connection_add_filter (priv->connection, dispatcher_filter_func, dispatcher, NULL);
  dbus_bus_request_name (priv->connection, DBUS_INTERFACE_STB, 0, &error);

  if (dbus_error_is_set (&error))
    {
      g_critical ("%s", error.message);
      dbus_error_free (&error);
    }

  dbus_connection_setup_with_g_main (priv->connection, NULL);
}

static void
stb_dispatcher_init (StbDispatcher *dispatcher)
{
  StbDispatcherPrivate *priv;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  dispatcher->_priv = priv;

  setup_connection (dispatcher);

  /* we're screwed if we don't have this */
  g_assert (priv->connection != NULL);

#ifdef HAVE_POLKIT
  priv->polkit_authority = polkit_authority_get ();
#endif

#ifdef HAVE_GIO
  priv->file_monitor = stb_file_monitor_new ();

  g_signal_connect_swapped (priv->file_monitor, "object_changed",
			    G_CALLBACK (object_changed_cb), dispatcher);
#endif
}

static void
stb_dispatcher_set_property (GObject      *object,
			     guint         prop_id,
			     const GValue *value,
			     GParamSpec   *pspec)
{
  switch (prop_id)
    {
    case PROP_DEBUG:
      stb_dispatcher_set_debug (STB_DISPATCHER (object),
				g_value_get_boolean (value));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
stb_dispatcher_get_property (GObject      *object,
			     guint         prop_id,
			     GValue       *value,
			     GParamSpec   *pspec)
{
  switch (prop_id)
    {
    case PROP_DEBUG:
      g_value_set_boolean (value,
			   stb_dispatcher_get_debug (STB_DISPATCHER (object)));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
stb_dispatcher_finalize (GObject *object)
{
  StbDispatcherPrivate *priv;

  priv = STB_DISPATCHER_GET_PRIVATE (object);

  dbus_connection_unref (priv->connection);

#ifdef HAVE_POLKIT
  g_object_unref (priv->polkit_authority);
#endif

#ifdef HAVE_GIO
  g_object_unref (priv->file_monitor);
#endif

  g_free (priv->platform);

  G_OBJECT_CLASS (stb_dispatcher_parent_class)->finalize (object);
}

static GObject*
stb_dispatcher_constructor (GType                  type,
			    guint                  n_construct_properties,
			    GObjectConstructParam *construct_params)
{
  static GObject *object = NULL;

  if (!object)
    object = G_OBJECT_CLASS (stb_dispatcher_parent_class)->constructor (type,
									n_construct_properties,
									construct_params);
  return object;
}

StbDispatcher*
stb_dispatcher_get (void)
{
  return g_object_new (STB_TYPE_DISPATCHER, NULL);
}

void
stb_dispatcher_set_debug (StbDispatcher *dispatcher,
			  gboolean       debug)
{
  StbDispatcherPrivate *priv;

  g_return_if_fail (STB_IS_DISPATCHER (dispatcher));

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  priv->debug = debug;
  g_object_notify (G_OBJECT (dispatcher), "debug");
}

gboolean
stb_dispatcher_get_debug (StbDispatcher *dispatcher)
{
  StbDispatcherPrivate *priv;

  g_return_val_if_fail (STB_IS_DISPATCHER (dispatcher), FALSE);

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  return priv->debug;
}
