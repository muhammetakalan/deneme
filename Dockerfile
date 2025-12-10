# 1. Aşama: Bağımlılıkları yükle (Deps)
FROM node:20-alpine AS deps
WORKDIR /app

# Paket yöneticisi dosyalarını kopyala
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

# Bağımlılıkları yükle (Lock dosyasına göre uygun yöntemi seçer)
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# 2. Aşama: Uygulamayı derle (Builder)
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js uygulamasını build et
# Eğer env değişkenlerine build sırasında ihtiyacınız varsa buraya ARG ekleyebilirsiniz.
RUN npm run build

# 3. Aşama: Çalıştırma (Runner) - Production imajı
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

# Güvenlik için root olmayan bir kullanıcı oluştur
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Public klasörünü ve standalone build dosyalarını kopyala
COPY --from=builder /app/public ./public
# .next/standalone klasörü, production için gerekli minimal dosyaları içerir
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]