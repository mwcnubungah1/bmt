from playwright.sync_api import sync_playwright


def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 900})
        page.goto("http://127.0.0.1:5173/", wait_until="networkidle")
        assert page.get_by_role("heading", name="Solusi Keuangan Syariah yang Amanah, Berkah, dan Berdaya.").is_visible()
        assert page.get_by_role("link", name="Daftar Anggota").is_visible()
        page.get_by_role("button", name="Simulasi Pembiayaan").click()
        page.get_by_label("Nominal pengajuan").fill("50000000")
        page.get_by_role("button", name="12").click()
        assert "4.666.667" in page.locator("#simulasi").inner_text()
        page.get_by_role("button", name="Ajukan Pembiayaan Berdasarkan Simulasi Ini").click()
        assert page.url.endswith("/login?next=%2Fnasabah%3Fview%3Dportal_get_loan_applications")
        assert page.evaluate("sessionStorage.getItem('bmt:public-murabahah-simulation')") is not None

        mobile = browser.new_page(viewport={"width": 390, "height": 844})
        mobile.goto("http://127.0.0.1:5173/", wait_until="networkidle")
        mobile.get_by_role("button", name="Buka menu").click()
        assert mobile.get_by_role("navigation", name="Navigasi mobile").is_visible()
        assert mobile.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
        browser.close()


if __name__ == "__main__":
    main()
