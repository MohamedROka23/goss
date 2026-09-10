import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { fetchProducts } from "./api";
import type { CartItem, Lang, Product } from "./types";

type Ctx = {
  lang: Lang;
  setLang: (lang: Lang) => void;
  products: Product[];
  reloadProducts: () => Promise<void>;
  cart: CartItem[];
  addToCart: (productId: string, qty?: number) => void;
  setQty: (productId: string, qty: number) => void;
  removeFromCart: (productId: string) => void;
  clearCart: () => void;
  token: string | null;
  setToken: (token: string | null) => void;
};

const AppCtx = createContext<Ctx | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Lang>(() => (localStorage.getItem("goss-lang") as Lang) || "en");
  const [products, setProducts] = useState<Product[]>([]);
  const [cart, setCart] = useState<CartItem[]>(() => {
    try {
      return JSON.parse(localStorage.getItem("goss-cart") || "[]");
    } catch {
      return [];
    }
  });
  const [token, setTokenState] = useState<string | null>(() => localStorage.getItem("goss-token"));

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
    localStorage.setItem("goss-lang", lang);
  }, [lang]);

  useEffect(() => {
    localStorage.setItem("goss-cart", JSON.stringify(cart));
  }, [cart]);

  const reloadProducts = async () => {
    setProducts(await fetchProducts());
  };

  useEffect(() => {
    reloadProducts().catch(() => undefined);
  }, []);

  const value = useMemo<Ctx>(
    () => ({
      lang,
      setLang,
      products,
      reloadProducts,
      cart,
      addToCart: (productId, qty = 1) => {
        setCart((prev) => {
          const found = prev.find((i) => i.productId === productId);
          if (found) return prev.map((i) => (i.productId === productId ? { ...i, qty: i.qty + qty } : i));
          return [...prev, { productId, qty }];
        });
      },
      setQty: (productId, qty) => {
        setCart((prev) => prev.map((i) => (i.productId === productId ? { ...i, qty: Math.max(1, qty) } : i)));
      },
      removeFromCart: (productId) => setCart((prev) => prev.filter((i) => i.productId !== productId)),
      clearCart: () => setCart([]),
      token,
      setToken: (t) => {
        setTokenState(t);
        if (t) localStorage.setItem("goss-token", t);
        else localStorage.removeItem("goss-token");
      },
    }),
    [lang, products, cart, token]
  );

  return <AppCtx.Provider value={value}>{children}</AppCtx.Provider>;
}

export function useApp() {
  const ctx = useContext(AppCtx);
  if (!ctx) throw new Error("useApp outside provider");
  return ctx;
}
