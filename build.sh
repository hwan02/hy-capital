#!/usr/bin/env bash
set -e
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.38.7 "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
flutter config --no-cli-animations
flutter pub get
# 서비스워커를 쓰지 않는다(--pwa-strategy=none).
# 기본값(offline-first)은 앱 파일을 기기에 저장해뒀다가, 배포해도 이미 열어본
# 기기엔 옛 버전을 먼저 띄웠다 — 고친 게 «안 고쳐진 것처럼» 보인 원인이다.
# 이 앱은 오프라인으로 쓸 일이 없다.
flutter build web --release --pwa-strategy=none \
  --dart-define=AUTO_EMAIL="$AUTO_EMAIL" \
  --dart-define=AUTO_PASSWORD="$AUTO_PASSWORD"

# 이미 옛 서비스워커가 깔린 기기용 «자폭» 워커. 브라우저가 이 파일이 바뀐 걸
# 보면 새로 설치하고, 저장해둔 캐시를 지운 뒤 스스로 등록을 풀고 한 번 새로고침한다.
cat > build/web/flutter_service_worker.js <<'SW'
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url);
  })());
});
SW
