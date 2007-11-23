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

#ifndef __STB_FILE_MONITOR_H
#define __STB_FILE_MONITOR_H

#include <glib-object.h>

G_BEGIN_DECLS

#define STB_TYPE_FILE_MONITOR         (stb_file_monitor_get_type ())
#define STB_FILE_MONITOR(o)           (G_TYPE_CHECK_INSTANCE_CAST ((o), STB_TYPE_FILE_MONITOR, StbFileMonitor))
#define STB_FILE_MONITOR_CLASS(c)     (G_TYPE_CHECK_CLASS_CAST ((c),    STB_TYPE_FILE_MONITOR, StbFileMonitorClass))
#define STB_IS_FILE_MONITOR(o)        (G_TYPE_CHECK_INSTANCE_TYPE ((o), STB_TYPE_FILE_MONITOR))
#define STB_IS_FILE_MONITOR_CLASS(c)  (G_TYPE_CHECK_CLASS_TYPE ((o),    STB_TYPE_FILE_MONITOR))
#define STB_FILE_MONITOR_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o),  STB_TYPE_FILE_MONITOR, StbFileMonitorClass))

typedef struct StbFileMonitor      StbFileMonitor;
typedef struct StbFileMonitorClass StbFileMonitorClass;

struct StbFileMonitor
{
  GObject parent;

  /*<private>*/
  gpointer _priv;
};

struct StbFileMonitorClass
{
  GObjectClass parent_class;

  void (* object_changed) (StbFileMonitor *file_monitor,
			   const gchar    *object);
};

GType           stb_file_monitor_get_type          (void);
StbFileMonitor *stb_file_monitor_new               (void);

void            stb_file_monitor_add_files         (StbFileMonitor  *file_monitor,
						    const gchar     *object,
						    const gchar    **files);
gboolean        stb_file_monitor_is_object_handled (StbFileMonitor  *file_monitor,
						    const gchar     *object);

G_END_DECLS

#endif /* __STB_FILE_MONITOR_H */
