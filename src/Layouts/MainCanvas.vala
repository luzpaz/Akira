/*
* Copyright (c) 2019-2020 Alecaddd (https://alecaddd.com)
*
* This file is part of Akira.
*
* Akira is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.

* Akira is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.

* You should have received a copy of the GNU General Public License
* along with Akira. If not, see <https://www.gnu.org/licenses/>.
*
* Authored by: Alessandro "Alecaddd" Castellani <castellani.ale@gmail.com>
* Authored by: Giacomo "giacomoalbe" Alberini <giacomoalbe@gmail.com>
*/
public class Akira.Layouts.MainCanvas : Gtk.Grid {
    public const int CANVAS_SIZE = 100000;
    public const double SCROLL_DISTANCE = 0;

    public Gtk.ScrolledWindow main_scroll;
    public Akira.Lib.Canvas canvas;
    public Gtk.Allocation main_window_size;
    public weak Akira.Window window { get; construct; }

    private Gtk.Overlay main_overlay;
    private Granite.Widgets.OverlayBar overlaybar;
    private Granite.Widgets.Toast notification;

    private double scroll_origin_x = 0;
    private double scroll_origin_y = 0;

    public MainCanvas (Akira.Window window) {
        Object (window: window, orientation: Gtk.Orientation.VERTICAL);
    }

    construct {
        window.event_bus.exporting.connect (on_exporting);
        window.event_bus.export_completed.connect (on_export_completed);
        window.event_bus.canvas_notification.connect (trigger_notification);

        get_allocation (out main_window_size);

        main_overlay = new Gtk.Overlay ();
        notification = new Granite.Widgets.Toast (_("Button was pressed!"));

        main_scroll = new Gtk.ScrolledWindow (null, null);
        main_scroll.expand = true;

        // Overlay the scrollbars only if mouse pointer is inside canvas
        main_scroll.overlay_scrolling = false;

        // Change visibility of canvas scrollbars
        main_scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.NEVER);

        canvas = new Akira.Lib.Canvas (window);

        canvas.set_size_request (main_window_size.width, main_window_size.height);
        canvas.set_bounds (0, 0, CANVAS_SIZE, CANVAS_SIZE);
        canvas.set_scale (1.0);

        canvas.update_bounds ();

        canvas.canvas_moved.connect ((event_x, event_y) => {
            // Move scroll window according to normalized mouse delta
            // relative to the scroll window, so with Canvas' pixel
            // coordinates translated into ScrolledWindow's one.
            double event_x_pixel_space = event_x;
            double event_y_pixel_space = event_y;

            // Convert coordinates to pixel space, which does account for
            // canvas scale and canvas translation.
            // Otherwise, delta can start to "diverge" due to the
            // translation of starting point happening during canvas translation
            canvas.convert_to_pixels (ref event_x_pixel_space, ref event_y_pixel_space);

            var delta_x = event_x_pixel_space - scroll_origin_x;
            var delta_y = event_y_pixel_space - scroll_origin_y;

            main_scroll.hadjustment.value -= delta_x;
            main_scroll.vadjustment.value -= delta_y;
        });

        canvas.canvas_scroll_set_origin.connect ((origin_x, origin_y) => {
            // Update scroll origin on Canvas' button_press_event
            scroll_origin_x = origin_x;
            scroll_origin_y = origin_y;

            canvas.convert_to_pixels (ref scroll_origin_x, ref scroll_origin_y);
        });

        canvas.scroll_event.connect (on_scroll);

        main_scroll.add (canvas);

        // Center canvas at startup
        main_scroll.hadjustment.value = CANVAS_SIZE / 2;
        main_scroll.vadjustment.value = CANVAS_SIZE / 2;

        main_overlay.add (main_scroll);
        main_overlay.add_overlay (notification);

        add (main_overlay);
    }

    public bool on_scroll (Gdk.EventScroll event) {
        bool is_shift = (event.state & Gdk.ModifierType.SHIFT_MASK) > 0;
        bool is_ctrl = (event.state & Gdk.ModifierType.CONTROL_MASK) > 0;

        double delta_x, delta_y;
        event.get_scroll_deltas (out delta_x, out delta_y);

        if (delta_y < -SCROLL_DISTANCE) {
            // Scroll UP
            if (is_ctrl) {
                // Zoom in
                window.headerbar.zoom.zoom_in ();
            } else if (is_shift) {
                main_scroll.hadjustment.value += delta_y * 10;
            } else {
                main_scroll.vadjustment.value += delta_y * 10;
            }
        } else if (delta_y > SCROLL_DISTANCE) {
            // Scoll DOWN
            if (is_ctrl) {
                // Zoom out
                window.headerbar.zoom.zoom_out ();
            } else if (is_shift) {
                main_scroll.hadjustment.value += delta_y * 10;
            } else {
                main_scroll.vadjustment.value += delta_y * 10;
            }
        }

        if (delta_x < -SCROLL_DISTANCE) {
            main_scroll.hadjustment.value += delta_x * 10;
        } else if (delta_x > SCROLL_DISTANCE) {
            main_scroll.hadjustment.value += delta_x * 10;
        }
        return true;
    }

    private async void on_exporting (string message) {
        overlaybar = new Granite.Widgets.OverlayBar (main_overlay);
        overlaybar.label = message;
        overlaybar.active = true;
        show_all ();
    }

    private async void on_export_completed () {
        main_overlay.remove (overlaybar);
        overlaybar = null;
        yield trigger_notification (_("Export completed!"));
    }

    private async void trigger_notification (string message) {
        notification.title = message;
        notification.send_notification ();
    }
}
