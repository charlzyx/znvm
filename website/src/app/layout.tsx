import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";

const inter = Inter({
  variable: "--font-sans",
  subsets: ["latin"],
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "znvm - Zero-overhead Node Version Manager",
    template: "%s | znvm",
  },
  description: "Node.js version manager built with Zig. Uses nvm's version layout and npmmirror by default. Measured 2026-10-22 on Linux: warm shell startup 3.31 ms, cold 5.01 ms.",
  keywords: ["znvm", "nvm", "fnm", "nvm-slow", "node version manager", "zig", "fast", "lightweight", "performance", "zero-overhead", "unix-philosophy", "minimalism", "性能", "零负担", "极简主义", "轻量级"],
  authors: [{ name: "charlzyx" }],
  openGraph: {
    title: "znvm - Zero-overhead Node Version Manager",
    description: "Node.js version manager built with Zig. Uses nvm's version layout and npmmirror by default.",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "znvm - Zero-overhead Node Version Manager",
    description: "Node.js version manager built with Zig. Uses nvm's version layout and npmmirror by default.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark scroll-smooth">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased min-h-screen bg-background font-sans text-foreground`}
      >
        <div className="relative flex min-h-screen flex-col">
          <Navbar />
          <main className="flex-1">{children}</main>
          <Footer />
        </div>
      </body>
    </html>
  );
}
