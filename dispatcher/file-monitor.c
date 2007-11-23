/* -*- Mode: C; c-file-style: "gnu"; tab-width: 8 -*- */
/* Copyright (C) 2007 Carlos Garnacho
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
#include <gio/gvfs.h>
#include <gio/gfilemonitor.h>
#include "file-monitor.h"

#define STB_FILE_MONITOR_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), STB_TYPE_FILE_MONITOR, StbFileMonitorPrivate))

enum {
  OBJECT_CHANGED,
  LAST_SIGNAL
};

typedef struct StbFileMonitorPrivate StbFileMonitorPrivate;

struct StbFileMonitorPrivate
{
  GHashTable *monitors;
};

static GQuark file_monitor_qdata;
static guint signals [LAST_SIGNAL];

static void stb_file_monitor_finalize (GObject *object);

G_DEFINE_TYPE (StbFileMonitor, stb_file_monitor, G_TYPE_OBJECT);

static void
stb_file_monitor_class_init (StbFileMonitorClass *class)
{
  GObjectClass *object_class = G_OBJECT_CLASS (class);

  object_class->finalize = stb_file_monitor_finalize;

  file_monitor_qdata = g_quark_from_static_string ("stb-file-monitor-data");

  signals [OBJECT_CHANGED] =
    g_signal_new ("object-changed",
		  G_OBJECT_CLASS_TYPE (object_class),
		  G_SIGNAL_RUN_LAST,
		  G_STRUCT_OFFSET (StbFileMonitorClass, object_changed),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__STRING,
		  G_TYPE_NONE, 1, G_TYPE_STRING);

  g_type_class_add_private (object_class,
			    sizeof (StbFileMonitorPrivate));
}

static void
destroy_monitor_list (gpointer data)
{
  GList *list = (GList *) data;

  g_list_foreach (list, (GFunc) g_object_unref, NULL);
  g_list_free (list);
}

static void
stb_file_monitor_init (StbFileMonitor *file_monitor)
{
  StbFileMonitorPrivate *priv;

  priv = STB_FILE_MONITOR_GET_PRIVATE (file_monitor);

  priv->monitors = g_hash_table_new_full (g_str_hash,
					  g_str_equal,
					  (GDestroyNotify) g_free,
					  (GDestroyNotify) destroy_monitor_list);
}

static void
stb_file_monitor_finalize (GObject *object)
{
  StbFileMonitorPrivate *priv;

  priv = STB_FILE_MONITOR_GET_PRIVATE (object);

  g_hash_table_unref (priv->monitors);

  G_OBJECT_CLASS (stb_file_monitor_parent_class)->finalize (object);
}

StbFileMonitor *
stb_file_monitor_new (void)
{
  return g_object_new (STB_TYPE_FILE_MONITOR, NULL);
}

static void
monitor_changed (GFileMonitor      *monitor,
		 GFile             *file,
		 GFile             *other_file,
		 GFileMonitorEvent  event,
		 gpointer           user_data)
{
  StbFileMonitor *file_monitor;
  const gchar *object;

  if (event == G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT)
    {
      file_monitor = STB_FILE_MONITOR (user_data);
      object = g_object_get_qdata (G_OBJECT (monitor), file_monitor_qdata);

      g_signal_emit (file_monitor, signals [OBJECT_CHANGED], 0, object);
    }
}

void
stb_file_monitor_add_files (StbFileMonitor  *file_monitor,
			    const gchar     *object,
			    const gchar    **files)
{
  StbFileMonitorPrivate *priv;
  GList *object_monitors;
  gchar *key;
  gint f;

  g_return_if_fail (STB_IS_FILE_MONITOR (file_monitor));

  priv = STB_FILE_MONITOR_GET_PRIVATE (file_monitor);

  if (stb_file_monitor_is_object_handled (file_monitor, object))
    return;

  key = g_strdup (object);
  object_monitors = NULL;

  for (f = 0; files[f]; f++)
    {
      GFileMonitor *monitor;
      GFile *file;

      file = g_file_new_for_path (files[f]);
      monitor = g_file_monitor_file (file, G_FILE_MONITOR_FLAGS_NONE, NULL);
      g_object_set_qdata (G_OBJECT (monitor), file_monitor_qdata, key);

      g_signal_connect (monitor, "changed",
			G_CALLBACK (monitor_changed), file_monitor);

      object_monitors = g_list_prepend (object_monitors, monitor);
    }

  g_hash_table_insert (priv->monitors, key, object_monitors);
}

gboolean
stb_file_monitor_is_object_handled (StbFileMonitor *file_monitor,
				    const gchar    *object)
{
  StbFileMonitorPrivate *priv;

  g_return_val_if_fail (STB_IS_FILE_MONITOR (file_monitor), FALSE);

  priv = STB_FILE_MONITOR_GET_PRIVATE (file_monitor);

  return (g_hash_table_lookup (priv->monitors, object) != NULL);
}
