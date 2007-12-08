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

#ifndef __STB_DISPATCHER_H
#define __STB_DISPATCHER_H

#include <glib-object.h>

G_BEGIN_DECLS

#define STB_TYPE_DISPATCHER         (stb_dispatcher_get_type ())
#define STB_DISPATCHER(o)           (G_TYPE_CHECK_INSTANCE_CAST ((o), STB_TYPE_DISPATCHER, StbDispatcher))
#define STB_DISPATCHER_CLASS(c)     (G_TYPE_CHECK_CLASS_CAST ((c),    STB_TYPE_DISPATCHER, StbDispatcherClass))
#define STB_IS_DISPATCHER(o)        (G_TYPE_CHECK_INSTANCE_TYPE ((o), STB_TYPE_DISPATCHER))
#define STB_IS_DISPATCHER_CLASS(c)  (G_TYPE_CHECK_CLASS_TYPE ((o),    STB_TYPE_DISPATCHER))
#define STB_DISPATCHER_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o),  STB_TYPE_DISPATCHER, StbDispatcherClass))

typedef struct StbDispatcher      StbDispatcher;
typedef struct StbDispatcherClass StbDispatcherClass;

struct StbDispatcher
{
  GObject parent;

  /*<private>*/
  gpointer _priv;
};

struct StbDispatcherClass
{
  GObjectClass parent_class;
};

GType          stb_dispatcher_get_type (void);

StbDispatcher *stb_dispatcher_get      (void);

void           stb_dispatcher_set_debug (StbDispatcher *dispatcher,
					 gboolean       debug);
gboolean       stb_dispatcher_get_debug (StbDispatcher *dispatcher);


G_END_DECLS

#endif /* __STB_DISPATCHER_H */
