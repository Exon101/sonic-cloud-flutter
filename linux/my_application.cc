#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  gchar* cwd = g_get_current_dir();
  GError* error = NULL;
  gint argc = g_strv_length(*arguments);
  GOptionContext* context = g_option_context_new("Sonic Cloud");
  GOptionEntry entries[] = {
    { "dart-entrypoint-args", 0, 0, G_OPTION_ARG_STRING_ARRAY, &self->dart_entrypoint_arguments, "Dart entrypoint arguments", "ARGS" },
    { NULL }
  };
  g_option_context_add_main_entries(context, entries, NULL);
  if (!g_option_context_parse_strv(context, arguments, &error)) {
     g_printerr("%s\n", error->message);
     g_error_free(error);
     *exit_status = 1;
     return TRUE;
  }
  g_option_context_free(context);
  g_free(cwd);

  return FALSE;
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "sonic_cloud");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  gtk_window_set_default_size(window, 420, 900);
  g_autoptr(FlView) view = fl_view_new(GTK_POLICY_NEVER);
  gtk_widget_show(GTK_WIDGET(view));
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);
  fl_engine_run_engine(engine, project, NULL);
  gtk_widget_show(GTK_WIDGET(window));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
}

static void my_application_finalize(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->finalize(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_OBJECT_CLASS(klass)->finalize = my_application_finalize;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(), "application-id", APPLICATION_ID, "flags", G_APPLICATION_NON_UNIQUE, NULL));
}
