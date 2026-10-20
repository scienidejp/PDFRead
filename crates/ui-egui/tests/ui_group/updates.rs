//! The private fork does not expose the upstream PdfCraft update checker.

#[test]
fn upstream_update_checker_is_not_registered() {
    assert!(pdfcraft_engine::commands::command("help.check_updates").is_none());
}
