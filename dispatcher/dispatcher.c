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

#include <glib.h>
#include <glib-object.h>
#include <dbus/dbus.h>
#include <dbus/dbus-glib-lowlevel.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>

#define DBUS_ADDRESS_ENVVAR "DBUS_SESSION_BUS_ADDRESS"
#define DBUS_INTERFACE_STB "org.freedesktop.SystemToolsBackends"
#define DBUS_INTERFACE_STB_PLATFORM "org.freedesktop.SystemToolsBackends.Platform"

/* FIXME: should be inside an object */
static GPid bus_pid = 0;
static guint watch_id = 0;
static gchar *platform = NULL;

typedef struct {
  DBusConnection *connection;
  gchar *destination;
  gint serial;
} AsyncData;

static void
async_data_free (AsyncData *data)
{
  dbus_connection_unref (data->connection);
  g_free (data->destination);
  g_free (data);
}

static void
retrieve_platform (DBusMessage *message)
{
      DBusMessageIter iter;
      const gchar *str;

      dbus_message_iter_init (message, &iter);
      dbus_message_iter_get_basic (&iter, &str);

      if (str && *str)
	platform = g_strdup (str);
}

static void
dispatch_reply (DBusPendingCall *pending_call,
		gpointer         data)
{
  DBusMessage *reply;
  AsyncData *async_data;

  reply = dbus_pending_call_steal_reply (pending_call);
  async_data = (AsyncData *) data;

  /* get the platform if necessary */
  if (dbus_message_has_interface (reply, DBUS_INTERFACE_STB_PLATFORM) &&
      dbus_message_has_member (reply, "getPlatform") && !platform)
    retrieve_platform (reply);

  /* send the reply back */
  dbus_message_set_destination (reply, async_data->destination);
  dbus_message_set_reply_serial (reply, async_data->serial);
  dbus_connection_send (async_data->connection, reply, NULL);

  dbus_message_unref (reply);
}

static gchar*
get_destination (DBusMessage *message)
{
  gchar **arr, *destination;

  if (!dbus_message_get_path_decomposed (message, &arr))
    return NULL;

  destination = g_strdup_printf (DBUS_INTERFACE_STB ".%s", arr[3]);
  dbus_free_string_array (arr);

  return destination;
}

static void
dispatch_stb_message (DBusConnection *connection,
		      DBusConnection *session_connection,
		      DBusMessage    *message)
{
  DBusMessage *copy;
  DBusPendingCall *pending_call;
  AsyncData *async_data;
  gchar *destination;

  if (dbus_message_has_interface (message, DBUS_INTERFACE_STB_PLATFORM))
    {
      if (dbus_message_has_member (message, "getPlatform") && platform)
	{
	  DBusMessage *reply;
	  DBusMessageIter iter;

	  /* create a reply with the stored platform */
	  reply = dbus_message_new_method_return (message);
	  dbus_message_iter_init_append (reply, &iter);
	  dbus_message_iter_append_basic (&iter, DBUS_TYPE_STRING, &platform);

	  dbus_connection_send (connection, reply, NULL);
	  dbus_message_unref (reply);

	  return;
	}
      else if (dbus_message_has_member (message, "setPlatform"))
	retrieve_platform (message);
    }

  destination = get_destination (message);
  copy = dbus_message_copy (message);

  /* there's something wrong with the message */
  if (!destination)
    return;

  /* forward the message to the corresponding service */
  dbus_message_set_destination (copy, destination);
  dbus_connection_send_with_reply (session_connection, copy, &pending_call, -1);

  if (pending_call)
    {
      async_data = g_new0 (AsyncData, 1);
      async_data->connection = dbus_connection_ref (connection);
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
  DBusConnection *session_connection = (DBusConnection *) data;

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
    dispatch_stb_message (connection, session_connection, message);

  return DBUS_HANDLER_RESULT_HANDLED;
}

static void
daemonize (void)
{
  int dev_null_fd, pidfile_fd;
  gchar *str;

  if (!getenv ("STB_NO_DAEMON"))
    {
      dev_null_fd = open ("/dev/null", O_RDWR);

      dup2 (dev_null_fd, 0);
      dup2 (dev_null_fd, 1);
      dup2 (dev_null_fd, 2);

      if (fork () != 0)
	exit (0);

      setsid ();

      if ((pidfile_fd = open ("/var/run/system-tools-backends.pid", O_WRONLY)) != -1)
	{
	  str = g_strdup_printf ("%d", getpid ());
	  write (pidfile_fd, str, strlen (str));
	  g_free (str);
	}
    }
}

static void
on_bus_term (GPid     pid,
	     gint     status,
	     gpointer data)
{
  g_spawn_close_pid (pid);
  bus_pid = 0;

  /* if the bus dies, we screwed up */
  g_critical ("Can't live without bus.");
  g_assert_not_reached ();
}

static DBusConnection*
get_private_bus (void)
{
  DBusConnection *connection = NULL;

  if (!bus_pid)
    {
      /* spawn private bus */
      static gchar *argv[] = { "dbus-daemon", "--session", "--print-address", "--nofork", NULL };
      gint output_fd;
      gchar str[300], *envvar;

      if (!g_spawn_async_with_pipes (NULL, argv, NULL,
				     G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD,
				     NULL, NULL, &bus_pid,
				     NULL, &output_fd, NULL, NULL))
	return NULL;

      watch_id = g_child_watch_add (bus_pid, on_bus_term, NULL);
      read (output_fd, str, sizeof (str));
      str[strlen(str) - 1] = '\0';

      envvar = g_strdup_printf (DBUS_ADDRESS_ENVVAR "=%s", str);
      putenv (envvar);

      /* get a connection with the newly created bus */
      connection = dbus_bus_get (DBUS_BUS_SESSION, NULL);
    }

  return connection;
}

void
on_sigterm (gint signal)
{
  /* terminate the private bus */
  if (bus_pid)
    {
      g_source_remove (watch_id);
      kill (bus_pid, SIGTERM);
    }

  exit (0);
}

int
main (int argc, char *argv[])
{
  DBusConnection *connection, *session_connection;
  GMainLoop *main_loop;
  DBusError error;

  /* Currently not necessary, we're not using objects */
  /* g_type_init (); */
  dbus_error_init (&error);

  daemonize ();
  signal (SIGTERM, on_sigterm);

  session_connection = get_private_bus ();
  connection = dbus_bus_get (DBUS_BUS_SYSTEM, &error);

  if (!session_connection || !connection)
    exit (-1);

  dbus_connection_set_exit_on_disconnect (connection, FALSE);
  dbus_connection_set_exit_on_disconnect (session_connection, FALSE);

  dbus_bus_request_name (connection, DBUS_INTERFACE_STB, 0, &error);
  dbus_connection_add_filter (connection, dispatcher_filter_func, session_connection, NULL);

  dbus_connection_setup_with_g_main (connection, NULL);
  dbus_connection_setup_with_g_main (session_connection, NULL);

  /* FIXME: error checking */

  main_loop = g_main_loop_new (NULL, FALSE);
  g_main_loop_run (main_loop);

  return 0;
}
