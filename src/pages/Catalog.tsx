import { FormEvent, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { submitRequest } from "../api";
import { useApp } from "../context";
import { CATEGORIES } from "../types";

export default function Catalog() {
  const { lang, products, cart, addToCart, setQty, removeFromCart, clearCart } = useApp();
  const en = lang === "en";
  const [params, setParams] = useSearchParams();
  const q = params.get("q") || "";
  const cat = params.get("cat") || "all";
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    return products.filter((p) => {
      const matchCat = cat === "all" || p.category === cat;
      const hay = `${p.nameEn} ${p.nameAr} ${p.descEn} ${p.descAr}`.toLowerCase();
      return matchCat && (!query || hay.includes(query));
    });
  }, [products, q, cat]);

  const lined = cart
    .map((c) => {
      const product = products.find((p) => p.id === c.productId);
      return product ? { ...c, product } : null;
    })
    .filter(Boolean) as { productId: string; qty: number; product: (typeof products)[0] }[];

  const total = lined.reduce((n, i) => n + i.product.price * i.qty, 0);

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError("");
    const form = new FormData(e.currentTarget);
    try {
      await submitRequest({
        company: String(form.get("company") || ""),
        name: String(form.get("name") || ""),
        phone: String(form.get("phone") || ""),
        email: String(form.get("email") || ""),
        notes: String(form.get("notes") || ""),
        items: lined.map((i) => ({
          productId: i.product.id,
          nameEn: i.product.nameEn,
          nameAr: i.product.nameAr,
          qty: i.qty,
          unit: i.product.unit,
          price: i.product.price,
        })),
      });
      clearCart();
      setSent(true);
      e.currentTarget.reset();
    } catch {
      setError(en ? "Could not send the request. Make sure the server is running." : "تعذر إرسال الطلب. تأكد أن الخادم يعمل.");
    }
  }

  return (
    <>
      <section className="page-hero">
        <h1>{en ? "Price Quotes & Product Search" : "عروض الأسعار والبحث عن المنتجات"}</h1>
        <p>
          {en
            ? "Search any item, add one or many products, then send a request. Gosst admin receives it instantly."
            : "ابحث عن أي منتج، أضف منتجاً واحداً أو عدة منتجات، ثم أرسل الطلب ليصل فوراً لإدارة جوست."}
        </p>
      </section>
      <section className="section">
        <div className="catalog-tools">
          <input
            value={q}
            onChange={(e) => {
              params.set("q", e.target.value);
              setParams(params);
            }}
            placeholder={en ? "Search a product..." : "ابحث عن منتج..."}
          />
          <select
            value={cat}
            onChange={(e) => {
              params.set("cat", e.target.value);
              setParams(params);
            }}
          >
            <option value="all">{en ? "All categories" : "كل الأقسام"}</option>
            {CATEGORIES.map((c) => (
              <option key={c.id} value={c.id}>{en ? c.en : c.ar}</option>
            ))}
          </select>
        </div>
        <div className="catalog-layout">
          <div className="grid grid-3">
            {filtered.map((p) => (
              <article className="card product-card" key={p.id}>
                <h3>{en ? p.nameEn : p.nameAr}</h3>
                <p className="muted">{en ? p.descEn : p.descAr}</p>
                <div className="price">EGP {p.price.toFixed(2)} / {p.unit}</div>
                <button className="btn btn-blue" onClick={() => addToCart(p.id)}>
                  {en ? "Add to request" : "أضف للطلب"}
                </button>
              </article>
            ))}
            {filtered.length === 0 && <p className="muted">{en ? "No products match your search." : "لا توجد منتجات مطابقة."}</p>}
          </div>
          <aside className="cart-panel">
            <h3>{en ? "Customer request" : "طلب العميل"}</h3>
            {lined.length === 0 && <p className="muted">{en ? "Add products from the catalog." : "أضف منتجات من الكتالوج."}</p>}
            {lined.map((i) => (
              <div key={i.productId} className="qty-row" style={{ marginBottom: 10 }}>
                <div style={{ flex: 1 }}>
                  <b>{en ? i.product.nameEn : i.product.nameAr}</b>
                  <div className="muted">EGP {(i.product.price * i.qty).toFixed(2)}</div>
                </div>
                <input
                  type="number"
                  min={1}
                  value={i.qty}
                  style={{ width: 64 }}
                  onChange={(e) => setQty(i.productId, Number(e.target.value))}
                />
                <button className="btn btn-ghost" onClick={() => removeFromCart(i.productId)}>×</button>
              </div>
            ))}
            <p><b>{en ? "Estimated total" : "الإجمالي التقديري"}: EGP {total.toFixed(2)}</b></p>
            {sent && <div className="notice">{en ? "Request sent. Gosst admin will see it now." : "تم إرسال الطلب. سيظهر الآن لدى الإدارة."}</div>}
            {error && <p className="muted">{error}</p>}
            <form className="form" onSubmit={onSubmit}>
              <input name="company" placeholder={en ? "Company" : "الشركة"} />
              <input name="name" required placeholder={en ? "Contact name" : "اسم المسؤول"} />
              <input name="phone" required placeholder={en ? "Phone" : "الهاتف"} />
              <input name="email" type="email" placeholder="Email" />
              <textarea name="notes" rows={3} placeholder={en ? "Notes" : "ملاحظات"} />
              <button className="btn btn-red" disabled={lined.length === 0}>
                {en ? "Send request" : "إرسال الطلب"}
              </button>
            </form>
          </aside>
        </div>
      </section>
    </>
  );
}
