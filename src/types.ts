export type Lang = "en" | "ar";

export type Product = {
  id: string;
  category: string;
  unit: string;
  price: number;
  nameEn: string;
  nameAr: string;
  descEn: string;
  descAr: string;
};

export type CartItem = {
  productId: string;
  qty: number;
};

export type RequestItem = {
  productId: string;
  nameEn: string;
  nameAr: string;
  qty: number;
  unit: string;
  price: number;
};

export type CustomerRequest = {
  id: string;
  createdAt: string;
  status: string;
  company: string;
  name: string;
  phone: string;
  email: string;
  notes: string;
  items: RequestItem[];
};

export const CATEGORIES = [
  { id: "vegetables", en: "Fresh Vegetables", ar: "خضروات طازجة" },
  { id: "fruits", en: "Fresh Fruits", ar: "فواكه طازجة" },
  { id: "hotel", en: "Hotel & Hospitality", ar: "مستلزمات الفنادق" },
  { id: "office", en: "Office Stationery", ar: "قرطاسية مكتبية" },
  { id: "packaging", en: "Packaging Materials", ar: "مواد التعبئة" },
] as const;
