{{flutter_js}}
{{flutter_build_config}}

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    const serviceWorkerUrl = new URL(
      'app_service_worker.js',
      document.baseURI,
    );
    navigator.serviceWorker.register(serviceWorkerUrl, {
      scope: document.baseURI,
      updateViaCache: 'none',
    }).catch(function (error) {
      console.warn('オフラインキャッシュを開始できませんでした。', error);
    });
  });
}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
