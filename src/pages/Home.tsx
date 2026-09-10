import { Link } from "react-router-dom";
import { useApp } from "./context";

export default function Home() {
  const { lang } = useApp();
  const en = lang === "en";

  return (
    <>
      <section className="hero">
        <div>
          <div className="tag">GOSST LOGISTICS & TRADE</div>
          <h1>{en ? "General Supplies & Trade" : "التوريدات العامة والتجارة"}</h1>
          <p>
            {en
              ? "Providing premium supplies for corporate sectors and the Hotels, Restaurants, and Catering industry."
              : "نوفر توريدات فاخرة للقطاعات المؤسسية وقطاع الفنادق والمطاعم والكيترينج."}
          </p>
          <div className="btns">
            <Link className="btn btn-blue" to="/logistics">{en ? "SERVICES" : "الخدمات"}</Link>
            <Link className="btn btn-red" to="/catalog">{en ? "REQUEST PRODUCTS" : "اطلب منتجات"}</Link>
          </div>
        </div>
      </section>

      <section className="section">
        <h2>{en ? "Our Main Services" : "خدماتنا الرئيسية"}</h2>
        <div className="grid grid-3" style={{ marginTop: 24 }}>
          {[
            ["Road Transport & Heavy Fleet", "النقل البري والأسطول الثقيل"],
            ["Sea Freight", "الشحن البحري"],
            ["Customs Clearance", "التخليص الجمركي"],
            ["Smart Warehousing", "التخزين الذكي"],
            ["Project Cargo & Heavy Lift", "الشحنات الثقيلة والمشروعات"],
            ["Fresh Vegetables", "خضروات طازجة"],
            ["Fresh Fruits", "فواكه طازجة"],
            ["Hotel & Hospitality Supplies", "مستلزمات الفنادق والضيافة"],
            ["Office Stationery", "القرطاسية المكتبية"],
            ["Packaging Materials", "مواد التعبئة"],
          ].map(([e, a]) => (
            <article className="card" key={e}><h3>{en ? e : a}</h3></article>
          ))}
        </div>
      </section>

      <section className="section alt">
        <h2>{en ? "About Gosst Co." : "عن شركة جوست"}</h2>
        <p className="lead">
          {en
            ? "Gosst is a premier supplier and logistics management corporation, delivering scalable and cost-effective solutions tailored for the corporate sectors and broad commercial trade. We operate under strict quality and compliance standards from our Alexandria hub."
            : "جوست شركة توريد وإدارة لوجستية رائدة تقدم حلولاً قابلة للتوسع وفعالة من حيث التكلفة للقطاعات المؤسسية والتجارة. نعمل وفق معايير جودة والتزام صارمة من مركزنا في الإسكندرية."}
        </p>
        <div className="grid grid-3" style={{ marginTop: 24 }}>
          <article className="card"><h3>{en ? "Officially Approved Suppliers" : "موردون معتمدون رسمياً"}</h3></article>
          <article className="card"><h3>{en ? "Certified Logistics Providers" : "مقدمو خدمات لوجستية معتمدون"}</h3></article>
          <article className="card"><h3>{en ? "Licensed Customs Brokers" : "وسطاء جمارك مرخصون"}</h3></article>
        </div>
      </section>

      <section className="section">
        <h2>{en ? "Our Working Process" : "آلية العمل"}</h2>
        <div className="grid grid-4" style={{ marginTop: 24 }}>
          {[
            ["Sourcing & Procurement", "التوريد والشراء", "Identifying and securing high-quality materials and products.", "تحديد وتأمين مواد ومنتجات عالية الجودة."],
            ["Quality Inspection", "فحص الجودة", "Rigorous quality checks to ensure compliance with standards.", "فحوصات جودة صارمة لضمان الالتزام بالمعايير."],
            ["Warehousing", "التخزين", "Secure storage and inventory management in modern facilities.", "تخزين آمن وإدارة مخزون في منشآت حديثة."],
            ["Road Transport & Delivery", "النقل والتسليم", "Efficient and reliable distribution to your designated locations.", "توزيع كفء وموثوق إلى مواقعكم المحددة."],
          ].map(([e, a, de, da]) => (
            <article className="card" key={e}>
              <h3>{en ? e : a}</h3>
              <p className="muted">{en ? de : da}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="section alt">
        <h2>{en ? "Core Values" : "قيمنا"}</h2>
        <div className="grid grid-3" style={{ marginTop: 24 }}>
          <article className="card">
            <h3>{en ? "Total Transparency" : "شفافية كاملة"}</h3>
            <p>{en ? "Clear pricing and honest communication at every step of our partnership." : "أسعار واضحة وتواصل صادق في كل خطوة من الشراكة."}</p>
          </article>
          <article className="card">
            <h3>{en ? "Strict Punctuality" : "التزام بالمواعيد"}</h3>
            <p>{en ? "Unwavering commitment to delivery schedules and operational deadlines." : "التزام ثابت بجداول التسليم والمواعيد التشغيلية."}</p>
          </article>
          <article className="card">
            <h3>{en ? "Uncompromising Quality" : "جودة بلا تنازل"}</h3>
            <p>{en ? "Rigorous vetting of all supplies to ensure they meet exact corporate standards." : "فحص دقيق لكل التوريدات لضمان مطابقة معايير الشركات."}</p>
          </article>
        </div>
      </section>
    </>
  );
}
