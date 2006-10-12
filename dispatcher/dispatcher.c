/* -*- Mode: C; c-file-style: "gnu"; tab-width: 8 -*- */
#include <glib.h>
#include <glib-object.h>
#include <dbus/dbus.h>
#include <dbus/dbus-glib-lowlevel.h>

#define DBUS_INTERFACE_STB "org.freedesktop.SystemToolsBackends"

typedef struct {
  DBusConnection *connection;
  DBusMessage *dummy_reply;
} AsyncData;

static void
async_data_free (AsyncData *data)
{
  dbus_connection_unref (data->connection);
  dbus_message_unref (data->dummy_reply);
  g_free (data);
}

static void
dispatch_reply (DBusPendingCall *pending_call,
		gpointer         data)
{
  DBusMessage *reply;
  AsyncData *async_data;

  reply = dbus_pending_call_steal_reply (pending_call);
  async_data = (AsyncData *) data;

  /* send the reply back */
  dbus_message_set_destination (reply, dbus_message_get_destination (async_data->dummy_reply));
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
  DBusMessage *dummy_reply;
  DBusPendingCall *pending_call;
  AsyncData *async_data;
  gchar *destination;

  destination = get_destination (message);

  /* there's something wrong with the message */
  if (!destination)
    return;

  /* get a dummy reply, we'll get the data
   * to create the correct reply from here */
  dummy_reply = dbus_message_new_method_return (message);

  /* forward the message to the corresponding service */
  dbus_message_set_destination (message, destination);

  /* send the message */
  async_data = g_new0 (AsyncData, 1);
  async_data->connection = dbus_connection_ref (connection);
  async_data->dummy_reply = dummy_reply;
  
  dbus_connection_send_with_reply (session_connection, message, &pending_call, -1);
  dbus_pending_call_set_notify (pending_call, dispatch_reply, async_data, (DBusFreeFunction) async_data_free);

  g_free (destination);
  dbus_pending_call_unref (pending_call);
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
	   dbus_message_has_interface (message, DBUS_INTERFACE_STB))
    dispatch_stb_message (connection, session_connection, message);

  return DBUS_HANDLER_RESULT_HANDLED;
}

int
main (int argc, char *argv[])
{
  DBusConnection *connection, *session_connection;
  GMainLoop *main_loop;
  DBusError error;

  g_type_init ();
  dbus_error_init (&error);

  connection = dbus_bus_get (DBUS_BUS_SYSTEM, &error);
  session_connection = dbus_bus_get (DBUS_BUS_SESSION, &error);
  dbus_connection_set_exit_on_disconnect (connection, FALSE);

  /* FIXME: error checking */

  dbus_bus_request_name (connection, "org.freedesktop.SystemToolsBackends", 0, &error);
  dbus_connection_add_filter (connection, dispatcher_filter_func, session_connection, NULL);

  dbus_connection_setup_with_g_main (connection, NULL);
  dbus_connection_setup_with_g_main (session_connection, NULL);
  main_loop = g_main_loop_new (NULL, FALSE);
  g_main_loop_run (main_loop);

  return 0;
}
