import { useApp } from "../context";

export default function About() {
  const { lang } = useApp();
  const en = lang === "en";
  return (
    <>
      <section className="page-hero">
        <h1>{en ? "About Gosst" : "عن جوست"}</h1>
        <p>{en ? "Your trusted partner in global supply chain, logistics, and premium trading solutions." : "شريككم الموثوق في سلاسل الإمداد والخدمات اللوجستية وحلول التجارة الفاخرة."}</p>
      </section>
      <section className="section">
        <h2>{en ? "Our Story" : "قصتنا"}</h2>
        <p className="lead">
          {en
            ? "Global Outsourcing Services & Trading (Gosst) is a premier holding company based in Alexandria, Egypt. We stand at the forefront of the global supply chain, delivering unparalleled excellence across logistics, warehousing, customs, and general supplies for corporate and hospitality clients."
            : "جلوبال أوتسورسنج سيرفسز آند تريدنج (جوست) شركة قابضة رائدة مقرها الإسكندرية، مصر. نعمل في مقدمة سلاسل الإمداد العالمية عبر اللوجستيات والتخزين والجمارك والتوريدات العامة لعملاء الشركات والضيافة."}
        </p>
        <p className="lead">
          {en
            ? "Driven by innovation and a commitment to absolute reliability, we leverage our expansive fleets and strategic warehousing networks to ensure that your operations run seamlessly."
            : "بدافع الابتكار والموثوقية نعتمد على أساطيل واسعة وشبكات تخزين استراتيجية لضمان تشغيل سلس لعملياتكم."}
        </p>
        <div className="grid grid-3" style={{ marginTop: 32 }}>
          <article className="card">
            <h3>{en ? "Our Mission" : "رسالتنا"}</h3>
            <p>{en ? "To deliver seamless, secure, and highly efficient supply chain and trading solutions that empower our clients' operations and drive sustainable growth." : "تقديم حلول سلاسل إمداد وتجارة سلسة وآمنة وكفؤة تمكّن عمليات عملائنا وتدفع نمواً مستداماً."}</p>
          </article>
          <article className="card">
            <h3>{en ? "Our Vision" : "رؤيتنا"}</h3>
            <p>{en ? "To be the leading and most trusted global logistics and outsourcing partner in the Middle East and beyond, setting new standards in service excellence." : "أن نكون الشريك اللوجستي والتعهيدي الأكثر ثقة في الشرق الأوسط وما بعده."}</p>
          </article>
        </div>
      </section>
      <section className="section alt">
        <h2>{en ? "Official Registrations & Accreditations" : "التسجيلات والاعتمادات الرسمية"}</h2>
        <div className="grid grid-3" style={{ marginTop: 24 }}>
          <article className="card">
            <h3>{en ? "Certified Suppliers" : "موردون معتمدون"}</h3>
            <p>{en ? "Officially registered and approved to supply corporate, industrial, and hospitality sectors with premium materials." : "مسجلون ومعتمدون رسمياً لتوريد القطاعات المؤسسية والصناعية والضيافة بمواد فاخرة."}</p>
          </article>
          <article className="card">
            <h3>{en ? "Certified Logistics Providers" : "مقدمو خدمات لوجستية معتمدون"}</h3>
            <p>{en ? "Fully accredited logistics operators ensuring secure, scalable, and standard-compliant global freight forwarding and transport." : "مشغّلون لوجستيون معتمدون لشحن ونقل عالمي آمن وقابل للتوسع ومتوافق مع المعايير."}</p>
          </article>
          <article className="card">
            <h3>{en ? "Certified Customs Brokers" : "وسطاء جمارك معتمدون"}</h3>
            <p>{en ? "Officially licensed brokers specialized in rapid port clearance, regulatory compliance, and processing standard import/export documentation seamlessly." : "وسطاء مرخصون متخصصون في التخليص السريع بالموانئ والامتثال ومعالجة وثائق الاستيراد والتصدير."}</p>
          </article>
        </div>
      </section>
    </>
  );
}
