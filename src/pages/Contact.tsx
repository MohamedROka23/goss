import { useApp } from "../context";

export default function Contact() {
  const { lang } = useApp();
  const en = lang === "en";
  return (
    <>
      <section className="page-hero">
        <h1>{en ? "Contact Us" : "تواصل معنا"}</h1>
        <p>{en ? "Book a consultation or send a product request from the quotes page." : "احجز استشارة أو أرسل طلب منتجات من صفحة عروض الأسعار."}</p>
      </section>
      <section className="section">
        <div className="grid grid-3">
          <article className="card">
            <h3>{en ? "Visit Us" : "العنوان"}</h3>
            <p>Alexandria, Egypt</p>
          </article>
          <article className="card">
            <h3>{en ? "Call Us" : "الهاتف"}</h3>
            <p><a href="tel:+201011428818">+20 10 11428818</a></p>
          </article>
          <article className="card">
            <h3>{en ? "Email Us" : "البريد"}</h3>
            <p><a href="mailto:info@gosst.com">info@gosst.com</a></p>
          </article>
        </div>
        <p style={{ marginTop: 24 }}>
          <a className="btn btn-red" href="https://wa.me/201011428818?text=Hello%20Gosst,%20I%20would%20like%20to%20inquire%20about%20your%20services">
            {en ? "Chat with us / تواصل معنا" : "تواصل معنا عبر واتساب"}
          </a>
        </p>
      </section>
    </>
  );
}
