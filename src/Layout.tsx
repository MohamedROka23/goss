import { NavLink, Outlet } from "react-router-dom";
import { useApp } from "./context";

const t = {
  en: {
    company: "GLOBAL OUTSOURCING SERVICES TRADING",
    visit: "Visit Us",
    email: "Email Us",
    call: "Call Us",
    home: "Home",
    about: "About Us",
    logistics: "Logistics & Services",
    supplies: "Supplies & Trade",
    catalog: "Price Quotes",
    contact: "Contact",
    admin: "Admin",
    request: "My Request",
    footer: "Delivering logistics excellence and premium supplies for your business needs.",
    copy: "© 2026 Gosst Co. All rights reserved.",
    quick: "Quick Links",
    core: "Core Services",
  },
  ar: {
    company: "جلوبال أوتسورسنج سيرفسز تريدنج",
    visit: "زورونا",
    email: "راسلونا",
    call: "اتصلوا بنا",
    home: "الرئيسية",
    about: "من نحن",
    logistics: "الخدمات اللوجستية",
    supplies: "التوريدات والتجارة",
    catalog: "عروض الأسعار",
    contact: "تواصل",
    admin: "الإدارة",
    request: "طلبي",
    footer: "نقدم تميزاً لوجستياً وتوريدات فاخرة لاحتياجات أعمالكم.",
    copy: "© 2026 شركة جوست. جميع الحقوق محفوظة.",
    quick: "روابط سريعة",
    core: "الخدمات الأساسية",
  },
};

export default function Layout() {
  const { lang, setLang, cart } = useApp();
  const copy = t[lang];
  const count = cart.reduce((n, i) => n + i.qty, 0);

  return (
    <>
      <div className="topbar">
        <span>{copy.company}</span>
        <div className="topbar-actions">
          <button className="lang-btn" onClick={() => setLang(lang === "en" ? "ar" : "en")}>
            {lang === "en" ? "العربية" : "English"}
          </button>
        </div>
      </div>
      <header className="header">
        <NavLink to="/" className="brand">
          <img src="/logo.png" alt="Gosst Logo" />
          <div>
            <strong>GOSST</strong>
            <small>Global Outsourcing Services Trading</small>
          </div>
        </NavLink>
        <div className="contacts">
          <div className="contact-item">
            <div className="icon">📍</div>
            <div>
              <b>{copy.visit}</b>
              <span>Alexandria, Egypt</span>
            </div>
          </div>
          <div className="contact-item">
            <div className="icon">✉</div>
            <div>
              <b>{copy.email}</b>
              <span>info@gosst.com</span>
            </div>
          </div>
          <div className="contact-item">
            <div className="icon">☎</div>
            <div>
              <b>{copy.call}</b>
              <span>+20 10 11428818</span>
            </div>
          </div>
        </div>
      </header>
      <nav className="nav">
        <NavLink to="/" end>{copy.home}</NavLink>
        <NavLink to="/about">{copy.about}</NavLink>
        <NavLink to="/logistics">{copy.logistics}</NavLink>
        <NavLink to="/supplies">{copy.supplies}</NavLink>
        <NavLink to="/catalog">{copy.catalog}</NavLink>
        <NavLink to="/contact">{copy.contact}</NavLink>
        <div className="nav-end">
          <NavLink to="/catalog">{copy.request}{count > 0 && <span className="badge">{count}</span>}</NavLink>
          <NavLink to="/admin">{copy.admin}</NavLink>
        </div>
      </nav>
      <Outlet />
      <footer className="footer">
        <div>
          <img src="/logo.png" alt="" style={{ width: 72 }} />
          <p>{copy.footer}</p>
        </div>
        <div>
          <h4>{copy.quick}</h4>
          <NavLink to="/">{copy.home}</NavLink>
          <NavLink to="/about">{copy.about}</NavLink>
          <NavLink to="/contact">{copy.contact}</NavLink>
        </div>
        <div>
          <h4>{copy.core}</h4>
          <NavLink to="/supplies">{copy.supplies}</NavLink>
          <NavLink to="/logistics">{copy.logistics}</NavLink>
        </div>
        <div>
          <h4>{copy.contact}</h4>
          <p>Alexandria, Egypt</p>
          <p>+20 10 11428818</p>
          <p>info@gosst.com</p>
        </div>
      </footer>
      <div className="copy">{copy.copy}</div>
    </>
  );
}
