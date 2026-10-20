//! The Home, Help and About surfaces use ReadPDF's own identity.

use egui_kittest::Harness;
use egui_kittest::kittest::Queryable;
use pdfcraft_ui_egui::{Dialog, PdfCraftApp};

fn harness(setup: impl FnOnce(&mut PdfCraftApp) + 'static) -> Harness<'static, PdfCraftApp> {
    let mut h = Harness::builder().with_size(egui::vec2(1400.0, 900.0)).build_eframe(move |_cc| {
        let mut app = PdfCraftApp::new();
        app.set_option("language", "en").unwrap();
        setup(&mut app);
        app
    });
    h.run_steps(4);
    h
}

#[test]
fn top_bar_has_no_discord_link() {
    let h = harness(|_| {});
    assert!(h.query_by_label("Discord").is_none());
}

#[test]
fn home_screen_has_no_upstream_community_branding() {
    let h = harness(|_| {});
    h.get_by_label_contains("Welcome to ReadPDF");
    assert!(h.query_by_label("ArtCraft").is_none());
}

#[test]
fn about_dialog_shows_readpdf_brand_and_attribution() {
    let pdf = b"%PDF-1.7\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF";
    // With a document open, so the home screen's own links are not on screen.
    let h = harness(move |app| {
        app.open_bytes("one.pdf", None, pdf.to_vec()).unwrap();
        app.dialog = Some(Dialog::About);
    });
    h.get_by_label("ReadPDF");
    h.get_by_label("A PDF application for reading, editing, and organizing documents.");
    h.get_by_label("Created by JFranken");
    assert!(h.query_by_label("ArtCraft").is_none());
    assert!(h.query_by_label("PdfCraft").is_none());
    assert!(h.query_by_label("Models").is_none());
    assert!(h.query_by_label("Contributors").is_none());
    assert!(h.query_by_label("Join our Discord").is_none());
}

#[test]
fn help_menu_has_no_upstream_links() {
    let mut h = harness(|_| {});
    h.get_by_label("Menu").click();
    h.run_steps(2);
    h.get_by_label("Help ⏵").hover();
    h.run_steps(2);
    for label in ["Discord", "PdfCraft", "ArtCraft", "GitHub", "Website", "Check for updates"] {
        assert!(h.query_by_label_contains(label).is_none(), "Help contains no {label} entry");
    }
    h.get_by_label_contains("About");
}
