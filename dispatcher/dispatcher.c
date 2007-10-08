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
 * Authors: Carlos Garnacho Parro  <carlosg@gnome.org>
 */

#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <glib.h>
#include <glib-object.h>
#include <dbus/dbus.h>
#include <dbus/dbus-glib-lowlevel.h>
#include "dispatcher.h"

#define DBUS_ADDRESS_ENVVAR "DBUS_SESSION_BUS_ADDRESS"
#define DBUS_INTERFACE_STB "org.freedesktop.SystemToolsBackends"
#define DBUS_INTERFACE_STB_PLATFORM "org.freedesktop.SystemToolsBackends.Platform"

#define STB_DISPATCHER_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), STB_TYPE_DISPATCHER, StbDispatcherPrivate))

typedef struct StbDispatcherPrivate   StbDispatcherPrivate;
typedef struct StbDispatcherAsyncData StbDispatcherAsyncData;

struct StbDispatcherPrivate
{
  DBusConnection *connection;
  DBusConnection *session_connection;

  GPid   bus_pid;
  guint  watch_id;
  gchar *platform;
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


G_DEFINE_TYPE (StbDispatcher, stb_dispatcher, G_TYPE_OBJECT);

static void
stb_dispatcher_class_init (StbDispatcherClass *class)
{
  GObjectClass *object_class = G_OBJECT_CLASS (class);

  object_class->constructor = stb_dispatcher_constructor;
  object_class->finalize    = stb_dispatcher_finalize;

  g_type_class_add_private (object_class,
			    sizeof (StbDispatcherPrivate));
}

static void
on_bus_term (GPid     pid,
	     gint     status,
	     gpointer data)
{
  StbDispatcher *dispatcher;
  StbDispatcherPrivate *priv;

  dispatcher = STB_DISPATCHER (data);
  priv = dispatcher->_priv;

  g_spawn_close_pid (priv->bus_pid);
  priv->bus_pid = 0;

  /* if the bus dies, we screwed up */
  g_critical ("Can't live without bus.");
  g_assert_not_reached ();
}

static void
setup_private_bus (StbDispatcher *dispatcher)
{
  StbDispatcherPrivate *priv;
  DBusError error;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);
  dbus_error_init (&error);

  if (!priv->bus_pid)
    {
      /* spawn private bus */
      static gchar *argv[] = { "dbus-daemon", "--session", "--print-address", "--nofork", NULL };
      gint output_fd, size;
      gchar *envvar;
      gchar str[300] = { 0, };

      if (!g_spawn_async_with_pipes (NULL, argv, NULL,
				     G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD,
				     NULL, NULL, &priv->bus_pid,
				     NULL, &output_fd, NULL, NULL))
	return;

      priv->watch_id = g_child_watch_add (priv->bus_pid, on_bus_term, dispatcher);
      size = read (output_fd, str, sizeof (str));
      str[size - 1] = '\0';

      envvar = g_strdup_printf (DBUS_ADDRESS_ENVVAR "=%s", str);
      putenv (envvar);

      /* get a connection with the newly created bus */
      priv->session_connection = dbus_bus_get (DBUS_BUS_SESSION, &error);

      if (dbus_error_is_set (&error))
	g_critical (error.message);

      dbus_connection_set_exit_on_disconnect (priv->session_connection, FALSE);
      dbus_connection_setup_with_g_main (priv->session_connection, NULL);
    }
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

static void
dispatch_reply (DBusPendingCall *pending_call,
		gpointer         data)
{
  StbDispatcherPrivate *priv;
  DBusMessage *reply;
  StbDispatcherAsyncData *async_data;

  reply = dbus_pending_call_steal_reply (pending_call);
  async_data = (StbDispatcherAsyncData *) data;
  priv = async_data->dispatcher->_priv;

  /* get the platform if necessary */
  if (dbus_message_has_interface (reply, DBUS_INTERFACE_STB_PLATFORM) &&
      dbus_message_has_member (reply, "getPlatform") && !priv->platform)
    priv->platform = retrieve_platform (reply);

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

static void
dispatch_stb_message (StbDispatcher *dispatcher,
		      DBusMessage   *message)
{
  StbDispatcherPrivate *priv;
  DBusMessage *copy;
  DBusPendingCall *pending_call;
  StbDispatcherAsyncData *async_data;
  gchar *destination;

  priv = STB_DISPATCHER_GET_PRIVATE (dispatcher);

  if (dbus_message_has_interface (message, DBUS_INTERFACE_STB_PLATFORM))
    {
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
    }

  destination = get_destination (message);

  /* there's something wrong with the message */
  if (G_UNLIKELY (!destination))
    {
      g_critical ("Could not get a valid destination, original one was: %s", dbus_message_get_path (message));
      return;
    }

  copy = dbus_message_copy (message);

  /* forward the message to the corresponding service */
  dbus_message_set_destination (copy, destination);
  dbus_connection_send_with_reply (priv->session_connection, copy, &pending_call, -1);

  if (pending_call)
    {
      async_data = g_new0 (StbDispatcherAsyncData, 1);
      async_data->dispatcher = g_object_ref (dispatcher);
      async_data->destination = g_strdup (dbus_message_get_sender (message));
      async_data->serial = dbus_message_get_serial (message);

      dbus_pending_call_set_notify (pending_call, dispatch_reply, async_data, (DBusFreeFunction) async_data_free);
      dbus_pending_call_unref (pending_call);
    }

  g_free (destination);
  dbus_message_unref (copy);
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
  else if (dbus_message_has_interface (message, DBUS_INTERFACE_INTROSPECTABLE) ||
	   dbus_message_has_interface (message, DBUS_INTERFACE_STB) ||
	   dbus_message_has_interface (message, DBUS_INTERFACE_STB_PLATFORM))
    dispatch_stb_message (dispatcher, message);

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
      g_critical (error.message);
      dbus_error_free (&error);
    }

  dbus_connection_set_exit_on_disconnect (priv->connection, FALSE);
  dbus_connection_add_filter (priv->connection, dispatcher_filter_func, dispatcher, NULL);
  dbus_bus_request_name (priv->connection, DBUS_INTERFACE_STB, 0, &error);

  if (dbus_error_is_set (&error))
    {
      g_critical (error.message);
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

  setup_private_bus (dispatcher);
  setup_connection (dispatcher);

  /* we're screwed if we don't have these */
  g_assert (priv->session_connection != NULL);
  g_assert (priv->connection != NULL);
}

static void
stb_dispatcher_finalize (GObject *object)
{
  StbDispatcherPrivate *priv;

  priv = STB_DISPATCHER_GET_PRIVATE (object);

  dbus_connection_unref (priv->session_connection);
  dbus_connection_unref (priv->connection);

  /* terminate the private bus */
  if (priv->bus_pid)
    {
      g_source_remove (priv->watch_id);
      priv->watch_id = 0;

      kill (priv->bus_pid, SIGTERM);
      priv->bus_pid = 0;
    }

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
