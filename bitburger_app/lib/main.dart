import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Importa esto para platform-specific checks si es necesario más adelante
// import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitBurger App',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Puedes personalizar el tema
        useMaterial3: true,
      ),
      home: const WebScreen(),
      debugShowCheckedModeBanner: false, // Oculta el banner de debug
    );
  }
}

class WebScreen extends StatefulWidget {
  const WebScreen({super.key});

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller; // Controlador para el WebView
  bool _isLoading = true; // Estado para mostrar/ocultar el indicador
  double _loadingProgress = 0; // Para mostrar progreso (opcional)

  // --- Configuración ---
  final String _websiteURL = "https://rccrawler.github.io/api-web-android-bit/us/";
  // Factor de Zoom (1.0 = 100%, 1.25 = 125%) - ¡AJUSTA ESTO!
  final double _pageZoomFactor = 1.25;
  // ---------------------

  @override
  void initState() {
    super.initState();

    // --- Inicializa el WebViewController ---
    _controller = WebViewController()
      // Habilita JavaScript (esencial)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Configura el NavigationDelegate para manejar eventos de carga
      ..setNavigationDelegate(
        NavigationDelegate(
          // --- Se llama cuando la carga comienza ---
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
            if (mounted) { // Asegura que el widget todavía esté en el árbol
              setState(() {
                _isLoading = true;
                _loadingProgress = 0; // Reinicia progreso
              });
            }
          },
          // --- Se llama cuando la carga termina ---
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            // Inyecta JavaScript para aplicar el zoom DESPUÉS de que la página cargó
            _applyZoom();
            // Oculta el indicador de carga (con un pequeño delay opcional para renderizado)
            // Future.delayed(const Duration(milliseconds: 300), () { // Delay opcional
               if (mounted) {
                 setState(() {
                   _isLoading = false;
                 });
               }
            // });
          },
          // --- Se llama si hay un error cargando ---
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
              Page resource error:
                code: ${error.errorCode}
                description: ${error.description}
                errorType: ${error.errorType}
                isForMainFrame: ${error.isForMainFrame}
                url: ${error.url}
            ''');
            if (mounted) {
              setState(() {
                _isLoading = false; // Oculta indicador en error
              });
              // Muestra un mensaje de error (opcional)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error cargando: ${error.description}'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          // --- Se llama para decidir si permitir o prevenir una navegación ---
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('Allowing navigation to ${request.url}');
            // Aquí podrías añadir lógica para bloquear ciertas URLs si quisieras
            return NavigationDecision.navigate; // Permite la navegación
          },
          // Actualiza el progreso de carga
           onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
            if (mounted) {
              setState(() {
                 _loadingProgress = progress / 100.0;
                 // Mantenemos isLoading=true hasta onPageFinished
                 // _isLoading = progress < 100;
              });
            }
          },
        ),
      )
      // Opcional: Configura un User Agent personalizado si es necesario
      // ..setUserAgent("miAppWebView/1.0")
      // Carga la URL inicial
      ..loadRequest(Uri.parse(_websiteURL));
  }

  // --- Función para inyectar JS y aplicar zoom ---
  void _applyZoom() {
    final String js = "document.body.style.zoom = '$_pageZoomFactor';";
    _controller.runJavaScript(js).then((_) {
       debugPrint("JS zoom applied successfully.");
    }).catchError((error) {
       debugPrint("Failed to apply JS zoom: $error");
    });
  }

  // --- Construcción de la UI ---
  @override
  Widget build(BuildContext context) {
    // PopScope maneja la navegación hacia atrás
    return PopScope(
      canPop: false, // Intercepta siempre el botón atrás
      onPopInvoked: (bool didPop) async {
        // Si el sistema ya hizo pop (ej. swipe en iOS), no hacemos nada
        if (didPop) {
           return;
        }
        // Comprueba si el WebView puede ir atrás
        final bool canGoBack = await _controller.canGoBack();
        if (canGoBack) {
           debugPrint("Navigating back in WebView");
           // Si puede, navega atrás en el historial del WebView
           await _controller.goBack();
        } else {
           debugPrint("No WebView history, allowing app to pop.");
           // Si no puede, permite que la app cierre la pantalla (o navegue atrás si hay más pantallas)
           // Usa maybePop para evitar errores si no hay nada a lo que volver
           Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        // AppBar opcional
        /*
        appBar: AppBar(
          title: const Text('BitBurger'),
          // Añadir botón de recarga (opcional)
          actions: [
             IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _controller.reload(),
             )
          ],
        ),
        */
        body: SafeArea( // Evita que el contenido se solape con áreas del sistema (notch, etc.)
          child: Stack(
            children: [
              // --- El WebView ---
              WebViewWidget(controller: _controller),

              // --- Indicador de Carga (superpuesto) ---
              if (_isLoading) // Muestra solo si _isLoading es true
                Container(
                  // Fondo semi-transparente opcional para atenuar la web detrás
                  // color: Colors.white.withOpacity(0.8),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null, // Muestra progreso si > 0
                    // valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // Color opcional
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}