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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <stdlib.h>
#include "dispatcher.h"
#include "config.h"

static StbDispatcher *dispatcher = NULL;

static void
daemonize (void)
{
  int dev_null_fd, pidfile_fd;
  gchar *str;

  dev_null_fd = open ("/dev/null", O_RDWR);

  dup2 (dev_null_fd, 0);
  dup2 (dev_null_fd, 1);
  dup2 (dev_null_fd, 2);

  if (fork () != 0)
    exit (0);

  setsid ();

  if ((pidfile_fd = open (LOCALSTATEDIR "/run/system-tools-backends.pid",
                          O_CREAT | O_WRONLY,
                          S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)) != -1)
    {
      str = g_strdup_printf ("%d", getpid ());
      write (pidfile_fd, str, strlen (str));
      g_free (str);

      close (pidfile_fd);
    }

  close (dev_null_fd);
}

static void
remove_pidfile (void)
{
  unlink (LOCALSTATEDIR "/run/system-tools-backends.pid");
}

void
signal_received (gint signal)
{
  switch (signal)
    {
    case SIGTERM:
    case SIGABRT:
      g_object_unref (dispatcher);
      remove_pidfile ();
      exit (0);
      break;
    default:
      break;
    }
}

int
main (int argc, char *argv[])
{
  GMainLoop *main_loop;
  gboolean debug = FALSE;
  gboolean daemon = FALSE;
  GOptionContext *context;
  GOptionEntry entries[] =
    {
      { "debug",     'd', 0, G_OPTION_ARG_NONE, &debug,     "Debug mode",     NULL },
      { "daemon",    'D', 0, G_OPTION_ARG_NONE, &daemon, "Daemon mode", NULL },
      /* Option kept for backward compatibility */
      { "no-daemon", 'n', G_OPTION_FLAG_HIDDEN | G_OPTION_FLAG_REVERSE,
                             G_OPTION_ARG_NONE, &daemon, "No daemon mode (default)", NULL },
      { NULL }
    };

  g_type_init ();

  /* parse options */
  context = g_option_context_new (NULL);
  g_option_context_add_main_entries (context, entries, NULL);
  g_option_context_parse (context, &argc, &argv, NULL);
  g_option_context_free (context);

  if (daemon)
    daemonize ();

  signal (SIGTERM, signal_received);
  dispatcher = stb_dispatcher_get ();

  if (G_UNLIKELY (debug))
    stb_dispatcher_set_debug (dispatcher, TRUE);

  main_loop = g_main_loop_new (NULL, FALSE);
  g_main_loop_run (main_loop);

  return 0;
}
