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
  description: "A blazingly fast Node.js version manager built with Zig. The ultimate nvm alternative that solves the nvm-slow problem. Starts in < 5ms.",
  keywords: ["znvm", "nvm", "fnm", "nvm-slow", "node version manager", "zig", "fast", "lightweight", "performance", "zero-overhead", "unix-philosophy", "minimalism", "性能", "零负担", "极简主义", "轻量级"],
  authors: [{ name: "charlzyx" }],
  openGraph: {
    title: "znvm - Zero-overhead Node Version Manager",
    description: "A blazingly fast Node.js version manager built with Zig",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "znvm - Zero-overhead Node Version Manager",
    description: "A blazingly fast Node.js version manager built with Zig",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased min-h-screen bg-background font-sans`}
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
