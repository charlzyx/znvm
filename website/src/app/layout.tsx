import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Navbar } from "@/components/navbar";
import { Footer } from "@/components/footer";
import { themeBootScript } from "@/lib/theme";

const siteUrl = "https://znvm.dev";

const inter = Inter({
  variable: "--font-sans",
  subsets: ["latin"],
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "znvm",
    template: "%s | znvm",
  },
  description: "nvm and nrm, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
  keywords: ["znvm", "nvm", "nrm", "node version manager", "zig", "npmmirror"],
  authors: [{ name: "charlzyx" }],
  openGraph: {
    title: "znvm",
    description: "nvm and nrm, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
    type: "website",
    locale: "en_US",
    images: [{ url: "/opengraph-image.png", width: 1200, height: 630, alt: "znvm" }],
    url: siteUrl,
  },
  twitter: {
    card: "summary_large_image",
    title: "znvm",
    description: "nvm and nrm, written in Zig. Versions in ~/.nvm. Node downloads from npmmirror.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootScript }} />
      </head>
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
