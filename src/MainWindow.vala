 /*
* Copyright © 2019 Alain M. (https://github.com/alainm23/planner)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Alain M. <alain23@protonmail.com>
*/

public class MainWindow : Gtk.Window {
    private Gtk.Entry name_entry;
    private Gtk.Entry color_entry;
    private Gtk.ColorButton color_button;
    private Gtk.SourceView source_view;
    private Gtk.SourceBuffer source_buffer;
    private Gtk.Button copy_button;

    private string TEMPLATE = """.ion-color-%s {
    --ion-color-base: %s;
    --ion-color-base-rgb: %s;
    --ion-color-contrast: %s;
    --ion-color-contrast-rgb: %s;
    --ion-color-shade: %s;
    --ion-color-tint: %s;
}
    """;
    public MainWindow (Application application) {
        Object (
            application: application,
            height_request: 500,
            width_request: 700,
            icon_name: "com.github.alainm23.ion-color-generator",
            title: "Ion Color Generator",
            resizable: false
        );
    }

    construct {
        var input_header = new Gtk.HeaderBar ();
        input_header.decoration_layout = "close:";
        input_header.show_close_button = true; 

        var input_header_context = input_header.get_style_context ();
        input_header_context.add_class ("input-header");
        input_header_context.add_class ("titlebar");
        input_header_context.add_class ("default-decoration");
        input_header_context.add_class (Gtk.STYLE_CLASS_FLAT);
    
        var output_header = new Gtk.HeaderBar ();
        output_header.hexpand = true;

        var output_header_context = output_header.get_style_context ();
        output_header_context.add_class ("output-header");
        output_header_context.add_class ("titlebar");
        output_header_context.add_class ("default-decoration");
        output_header_context.add_class (Gtk.STYLE_CLASS_FLAT);

        var header_grid = new Gtk.Grid ();
        header_grid.add (input_header);
        header_grid.add (output_header);

        // Main Grid
        var name_label = new Granite.HeaderLabel (_("Color Name"));
        name_label.margin_top = 6;
        name_entry = new Gtk.Entry ();

        var header_label = new Granite.HeaderLabel (_("Base Color"));

        color_entry = new Gtk.Entry ();
        color_entry.placeholder_text = "#7239b3";
        color_entry.max_length = 7;

        color_button = new Gtk.ColorButton ();

        var color_grid = new Gtk.Grid ();
        color_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        color_grid.add (color_entry);
        color_grid.add (color_button);

        copy_button = new Gtk.Button.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.MENU);
        copy_button.always_show_image = true;
        copy_button.sensitive = false;
        copy_button.label = _("Copy");
        copy_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var left_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        left_box.margin = 12;
        left_box.margin_top = 0;
        left_box.pack_start (header_label, false, false, 0);
        left_box.pack_start (color_grid, false, false, 0);
        left_box.pack_start (name_label, false, false, 0);
        left_box.pack_start (name_entry, false, false, 0);
        left_box.pack_end (copy_button, false, false, 0);

        // Source Buffer
        source_buffer = new Gtk.SourceBuffer (null);
        source_buffer.highlight_syntax = true;
        source_buffer.language = Gtk.SourceLanguageManager.get_default ().get_language ("scss");
        source_buffer.style_scheme = new Gtk.SourceStyleSchemeManager ().get_scheme ("solarized-light");

        // Source View
        source_view = new Gtk.SourceView ();
        source_view.left_margin = 12;
        source_view.show_line_numbers = false;
        source_view.monospace = true;
        source_view.expand = true;
        source_view.buffer = source_buffer;

        var toast = new Granite.Widgets.Toast (_("Copy to clipboard!!!"));

        var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        right_box.pack_start (source_view, true, true, 0);
        right_box.pack_end (toast, false, false, 0);

        var main_grid = new Gtk.Grid ();
        main_grid.add (left_box);
        main_grid.add (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        main_grid.add (right_box); 

        var sizegroup = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        sizegroup.add_widget (left_box);
        sizegroup.add_widget (input_header);

        add (main_grid);
        get_style_context ().add_class ("rounded");
        set_titlebar (header_grid);

        name_entry.changed.connect (update_template);
        color_entry.changed.connect (update_template);
        color_button.color_set.connect (() => {
            string hex = rgb_to_hex_string (color_button.rgba);
            color_entry.text = hex;
        });

        copy_button.clicked.connect (() => {
            Gtk.Clipboard.get_default (get_display ()).set_text (source_buffer.text, -1);
            toast.send_notification ();
        });
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        int root_x, root_y;
        get_position (out root_x, out root_y);
        Application.settings.set_value ("window-position",  new int[] { root_x, root_y });

        return base.configure_event (event);
    }

    private void update_template () {
        Gdk.RGBA rgba = Gdk.RGBA ();
        
        if (rgba.parse (color_entry.text)) {
            copy_button.sensitive = true;
            color_button.rgba = rgba;

            source_buffer.text = TEMPLATE.printf (
                name_entry.text,
                color_entry.text,
                "%s, %s, %s".printf (double_to_string (rgba.red * 255), double_to_string (rgba.green * 255), double_to_string (rgba.blue * 255)),
                get_contrast (color_entry.text),
                get_contrast_to_rgb (get_contrast (color_entry.text)),
                calculate_shade (color_entry.text),
                calculate_tint (color_entry.text)
            );
        } else {
            copy_button.sensitive = false;
        }
    }

    private string double_to_string (double d) {
        return d.to_string ();
    }

    private string rgb_to_hex_string (Gdk.RGBA rgba) {
        string s = "#%02x%02x%02x".printf(
            (uint) (rgba.red * 255),
            (uint) (rgba.green * 255),
            (uint) (rgba.blue * 255));
        return s;
    }

    public string get_contrast (string hex) {
        var gdk_white = Gdk.RGBA ();
        gdk_white.parse ("#fff");

        var gdk_black = Gdk.RGBA ();
        gdk_black.parse ("#000");

        var gdk_bg = Gdk.RGBA ();
        gdk_bg.parse (hex);

        var contrast_white = contrast_ratio (
            gdk_bg,
            gdk_white
        );

        var contrast_black = contrast_ratio (
            gdk_bg,
            gdk_black
        );

        var fg_color = "#fff";

        // NOTE: We cheat and add 3 to contrast when checking against black,
        // because white generally looks better on a colored background
        if (contrast_black > (contrast_white + 3)) {
            fg_color = "#000";
        }

        return fg_color;
    }

    private double contrast_ratio (Gdk.RGBA bg_color, Gdk.RGBA fg_color) {
        var bg_luminance = get_luminance (bg_color);
        var fg_luminance = get_luminance (fg_color);

        if (bg_luminance > fg_luminance) {
            return (bg_luminance + 0.05) / (fg_luminance + 0.05);
        }

        return (fg_luminance + 0.05) / (bg_luminance + 0.05);
    }

    private double get_luminance (Gdk.RGBA color) {
        var red = sanitize_color (color.red) * 0.2126;
        var green = sanitize_color (color.green) * 0.7152;
        var blue = sanitize_color (color.blue) * 0.0722;

        return (red + green + blue);
    }

    private double sanitize_color (double color) {
        if (color <= 0.03928) {
            return color / 12.92;
        }

        return Math.pow ((color + 0.055) / 1.055, 2.4);
    }

    private string get_contrast_to_rgb (string hex) {
        Gdk.RGBA rgba = Gdk.RGBA ();
        rgba.parse (hex);
        return "%s, %s, %s".printf (double_to_string (rgba.red * 255), double_to_string (rgba.green * 255), double_to_string (rgba.blue * 255));
    }

    private string calculate_tint (string hex) {
        Gdk.RGBA rgba = Gdk.RGBA ();
        rgba.parse (hex);

        //102 + ((255 - 102) x .1)
        double r = (rgba.red * 255) + ((255 - rgba.red * 255) * 0.1); 
        double g = (rgba.green * 255) + ((255 - rgba.green * 255) * 0.1); 
        double b = (rgba.blue * 255) + ((255 - rgba.blue * 255) * 0.1); 

        Gdk.RGBA new_rgba = Gdk.RGBA ();
        new_rgba.parse ("rgb (%s, %s, %s)".printf (r.to_string (), g.to_string (), b.to_string ()));

        return rgb_to_hex_string (new_rgba);
    }

    private string calculate_shade (string hex) {
        Gdk.RGBA rgba = Gdk.RGBA ();
        rgba.parse (hex);

        //102 x .9 = 91.8
        double r = (rgba.red * 255) * 0.9;
        double g = (rgba.green * 255) * 0.9;
        double b = (rgba.blue * 255) * 0.9;

        Gdk.RGBA new_rgba = Gdk.RGBA ();
        new_rgba.parse ("rgb (%s, %s, %s)".printf (r.to_string (), g.to_string (), b.to_string ()));

        return rgb_to_hex_string (new_rgba);
    }
}