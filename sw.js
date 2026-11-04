// Service worker do RDO Venko — permite "instalar como app" no celular/tablet
// (PWA) e also usar o app com o wi-fi/dados desligados. Estratégia:
// network-first (sempre busca a versão mais nova primeiro) com um cache
// local como fallback só para quando o dispositivo estiver offline.
//
// Chamadas para a Supabase (API/dados) NUNCA passam por aqui — sempre vão
// direto pra rede, sem cache, porque são dados que mudam e o app já tem
// sua própria lógica de rascunho offline para RDOs.
//
// As bibliotecas externas fixas abaixo (jsPDF, html2canvas, supabase-js)
// SÃO cacheadas: sem elas o app trava ao tentar abrir sem internet, porque
// o próprio código do site depende delas para existir (ex.: window.supabase).

const CACHE_NAME = 'rdo-venko-v2';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png'
];
const EXTERNAL_LIBS = [
  'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'
];

self.addEventListener('install', function(event){
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache){
        return cache.addAll(APP_SHELL)
          .catch(function(){ /* ok se algum item falhar (ex.: offline no primeiro load) */ })
          .then(function(){
            return Promise.all(EXTERNAL_LIBS.map(function(url){
              return fetch(url, { mode:'cors' })
                .then(function(res){ if(res && res.ok) return cache.put(url, res); })
                .catch(function(){ /* sem internet no primeiro load: tenta de novo depois */ });
            }));
          });
      })
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
  var isSameOrigin = (url.origin === self.location.origin);
  var isCachedExternalLib = EXTERNAL_LIBS.indexOf(req.url) !== -1;

  if(!isSameOrigin && !isCachedExternalLib) return; // nunca mexe em Supabase nem em outras chamadas externas

  event.respondWith(
    fetch(req)
      .then(function(res){
        var copy = res.clone();
        caches.open(CACHE_NAME).then(function(cache){ cache.put(req, copy); }).catch(function(){});
        return res;
      })
      .catch(function(){
        return caches.match(req).then(function(cached){
          return cached || (isSameOrigin ? caches.match('./index.html') : undefined);
        });
      })
  );
});

// v58 — notificação no celular (aviso de RDO não feito). O texto vem cifrado do servidor da Venko.
self.addEventListener('push', function (event) {
  var d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { mensagem: event.data ? event.data.text() : '' }; }
  var titulo = d.titulo || 'RDO Venko';
  event.waitUntil(self.registration.showNotification(titulo, {
    body: d.mensagem || '',
    icon: 'icon-192.png',
    badge: 'icon-192.png',
    tag: d.tag || 'rdo-venko',
    renotify: true,
    data: { link: d.link || './index.html#avisos' }
  }).then(function () {
    // v64: avisa as telas abertas do sistema para atualizarem o sininho na hora
    return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (lista) {
      lista.forEach(function (c) { try { c.postMessage({ tipo: 'vk-aviso' }); } catch (e) {} });
    });
  }));
});
// v64: quando o navegador troca a inscrição sozinho, já refaz com a mesma chave (o sistema grava no servidor na próxima abertura)
self.addEventListener('pushsubscriptionchange', function (event) {
  var velha = event.oldSubscription, chave = velha && velha.options && velha.options.applicationServerKey;
  if (!chave) return;
  event.waitUntil(self.registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: chave }).catch(function () {}));
});
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var destino = new URL((event.notification.data && event.notification.data.link) || './index.html#avisos', self.registration.scope).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (lista) {
    for (var i = 0; i < lista.length; i++) {
      var c = lista[i];
      if (c.url.indexOf(self.registration.scope) === 0 && 'focus' in c) {
        return c.focus().then(function (cf) { return cf && 'navigate' in cf ? cf.navigate(destino) : cf; }).catch(function () {});
      }
    }
    return self.clients.openWindow(destino);
  }));
});
