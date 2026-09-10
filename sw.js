// Service worker do RDO Venko — só existe para permitir "instalar como app"
// no celular/tablet (PWA). Estratégia: network-first para tudo do mesmo
// domínio (sempre busca a versão mais nova primeiro), com um cache local
// como fallback só para quando o dispositivo estiver offline. Nunca
// intercepta chamadas para a Supabase nem para CDNs externas — essas vão
// sempre direto pra rede, sem cache.

const CACHE_NAME = 'rdo-venko-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', function(event){
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache){ return cache.addAll(APP_SHELL); })
      .catch(function(){ /* ok se algum item falhar (ex.: offline no primeiro load) */ })
  );
});

self.addEventListener('activate', function(event){
  event.waitUntil(
    caches.keys()
      .then(function(keys){
        return Promise.all(keys.filter(function(k){ return k !== CACHE_NAME; }).map(function(k){ return caches.delete(k); }));
      })
      .then(function(){ return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function(event){
  var req = event.request;
  if(req.method !== 'GET') return;

  var url = new URL(req.url);
  if(url.origin !== self.location.origin) return; // nunca mexe em Supabase/CDN

  event.respondWith(
    fetch(req)
      .then(function(res){
        var copy = res.clone();
        caches.open(CACHE_NAME).then(function(cache){ cache.put(req, copy); }).catch(function(){});
        return res;
      })
      .catch(function(){
        return caches.match(req).then(function(cached){
          return cached || caches.match('./index.html');
        });
      })
  );
});
