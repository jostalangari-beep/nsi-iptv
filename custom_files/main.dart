import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NsiIptvApp());
}

class NsiIptvApp extends StatelessWidget {
  const NsiIptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSI IPTV',
      debugShowCheckedModeBanner: false,
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF161F30),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class Channel {
  final String name;
  final String group;
  final String logo;
  final String url;

  Channel({
    required this.name,
    required this.group,
    required this.logo,
    required this.url,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController(
    text: 'http://192.168.2.150/playlist.m3u',
  );

  List<Channel> _allChannels = [];
  List<String> _categories = ['Todos'];
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadPlaylist(_urlController.text.trim());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist(String m3uUrl) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final uri = Uri.parse(m3uUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes, allowMalformed: true);
        final parsed = _parseM3u(content, uri);

        if (parsed.isEmpty) {
          setState(() {
            _errorMsg =
                'Se conectó al servidor, pero no se encontraron canales válidos en la lista.';
            _isLoading = false;
          });
          return;
        }

        final Set<String> groups = {'Todos'};
        for (var ch in parsed) {
          groups.add(ch.group);
        }

        setState(() {
          _allChannels = parsed;
          _categories = groups.toList();
          _selectedCategory = 'Todos';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg =
              'El servidor respondió con código ${response.statusCode}. Verifica la ruta del archivo M3U.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg =
            'No se pudo conectar a:\n$m3uUrl\n\nVerifica que estés en el WiFi/Fibra de NSI y que la ruta o puerto sea el exacto.\nDetalle: $e';
        _isLoading = false;
      });
    }
  }

  void _openDirectStream(String directUrl) {
    final testChannel = Channel(
      name: 'Prueba Directa NSI',
      group: 'Directo',
      logo: '',
      url: directUrl,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channels: [testChannel],
          initialIndex: 0,
        ),
      ),
    );
  }

  List<Channel> _parseM3u(String content, Uri baseUri) {
    final List<Channel> channels = [];
    final lines = const LineSplitter().convert(content);

    String currentName = 'Canal NSI';
    String currentGroup = 'Canales en Vivo';
    String currentLogo = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        currentGroup = (groupMatch != null && groupMatch.group(1)!.isNotEmpty)
            ? groupMatch.group(1)!
            : 'General';

        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        currentLogo = logoMatch != null ? logoMatch.group(1)! : '';

        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex + 1 < line.length) {
          currentName = line.substring(commaIndex + 1).trim();
        }
      } else if (!line.startsWith('#')) {
        String streamUrl = line;
        if (streamUrl.startsWith('/')) {
          final portPart = baseUri.hasPort ? ':${baseUri.port}' : '';
          streamUrl = '${baseUri.scheme}://${baseUri.host}$portPart$streamUrl';
        }

        channels.add(
          Channel(
            name: currentName,
            group: currentGroup,
            logo: currentLogo,
            url: streamUrl,
          ),
        );

        currentName = 'Canal ${channels.length + 1}';
        currentGroup = 'Canales en Vivo';
        currentLogo = '';
      }
    }
    return channels;
  }

  void _showUrlConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text('Configurar Servidor NSI S.A.S.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa la URL de tu lista M3U o el enlace directo de un canal de tu servidor (Astra / Jellyfin):',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black38,
                hintText: 'http://192.168.2.150:puerto/lista.m3u',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () {
              final url = _urlController.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty) {
                _openDirectStream(url);
              }
            },
            child: const Text('Abrir Canal Directo'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _loadPlaylist(_urlController.text.trim());
            },
            child: const Text('Cargar Lista M3U'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChannels = _allChannels.where((ch) {
      final matchesCat =
          _selectedCategory == 'Todos' || ch.group == _selectedCategory;
      final matchesSearch =
          ch.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NSI IPTV',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (isWide)
              const Text(
                'Televisión Digital por Fibra Óptica',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cambiar URL del Servidor',
            icon: const Icon(Icons.settings_ethernet, color: Color(0xFF00E5FF)),
            onPressed: _showUrlConfigDialog,
          ),
          IconButton(
            tooltip: 'Recargar Canales',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadPlaylist(_urlController.text.trim()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar canal en vivo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF1F2937),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: const Color(0xFFE50914),
                          backgroundColor: const Color(0xFF1F2937),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFE50914)),
                        SizedBox(height: 16),
                        Text('Conectando al servidor local NSI...'),
                      ],
                    ),
                  )
                : _errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 60,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMsg!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Configurar URL'),
                                    onPressed: _showUrlConfigDialog,
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reintentar'),
                                    onPressed: () => _loadPlaylist(
                                      _urlController.text.trim(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 5 : 2,
                          childAspectRatio: 1.35,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredChannels.length,
                        itemBuilder: (context, index) {
                          final channel = filteredChannels[index];
                          return ChannelCard(
                            channel: channel,
                            indexNumber: index + 1,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    channels: filteredChannels,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ChannelCard extends StatefulWidget {
  final Channel channel;
  final int indexNumber;
  final VoidCallback onTap;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.indexNumber,
    required this.onTap,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF00E5FF)
                  : const Color(0x14FFFFFF),
              width: _isFocused ? 3.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? const [
                    BoxShadow(
                      color: Color(0x6600E5FF),
                      blurRadius: 10,
                    )
                  ]
                : const [],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: widget.channel.logo.isNotEmpty
                    ? Image.network(
                        widget.channel.logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.live_tv_rounded,
                          size: 38,
                          color: Colors.white54,
                        ),
                      )
                    : const Icon(
                        Icons.live_tv_rounded,
                        size: 38,
                        color: Color(0xFFE50914),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.indexNumber}. ${widget.channel.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                widget.channel.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _currentIndex;
  VlcPlayerController? _vlcController;
  bool _useSoftwareDecoding = true;
  bool _showControls = true;
  bool _volumeInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  void _initPlayer() {
    _volumeInitialized = false;
    final currentUrl = widget.channels[_currentIndex].url;

    _vlcController = VlcPlayerController.network(
      currentUrl,
      hwAcc: _useSoftwareDecoding ? HwAcc.disabled : HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2500),
        ]),
      ),
    );

    _vlcController!.addListener(() {
      if (mounted &&
          !_volumeInitialized &&
          _vlcController != null &&
          _vlcController!.value.isPlaying) {
        _volumeInitialized = true;
        _vlcController!.setVolume(100);
      }
    });
  }

  Future<void> _changeChannel(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.channels.length) return;
    _volumeInitialized = false;
    setState(() {
      _currentIndex = newIndex;
    });
    await _vlcController?.setMediaFromNetwork(
      widget.channels[_currentIndex].url,
      autoPlay: true,
      hwAcc: _useSoftwareDecoding ? HwAcc.disabled : HwAcc.full,
    );
  }

  Future<void> _toggleDecoderMode() async {
    final oldController = _vlcController;
    setState(() {
      _useSoftwareDecoding = !_useSoftwareDecoding;
      _vlcController = null;
    });
    await oldController?.stop();
    await oldController?.dispose();
    _initPlayer();
    setState(() {});
  }

  Future<void> _selectAudioTrack() async {
    if (_vlcController == null) return;
    final tracks = await _vlcController!.getAudioTracks();
    final activeTrack = await _vlcController!.getAudioTrack();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161F30),
      builder: (ctx) {
        if (tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Este canal solo reporta una pista de audio predeterminada o aún está cargando el flujo.',
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Seleccionar Pista de Audio (Satélite / Astra)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...tracks.entries.map((entry) {
              return ListTile(
                leading: Icon(
                  entry.key == activeTrack
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: const Color(0xFF00E5FF),
                ),
                title: Text('Pista ${entry.key}: ${entry.value}'),
                onTap: () async {
                  await _vlcController!.setAudioTrack(entry.key);
                  await _vlcController!.setVolume(100);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _vlcController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChannel = widget.channels[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: _vlcController != null
                  ? VlcPlayer(
                      controller: _vlcController!,
                      aspectRatio: 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE50914),
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentChannel.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      currentChannel.url,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                ),
                                icon: const Icon(
                                  Icons.audiotrack,
                                  size: 18,
                                  color: Color(0xFF00E5FF),
                                ),
                                label: const Text('Pista Audio'),
                                onPressed: _selectAudioTrack,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _useSoftwareDecoding
                                      ? const Color(0xFFE50914)
                                      : const Color(0xFF1E293B),
                                ),
                                icon: const Icon(Icons.memory, size: 18),
                                label: Text(
                                  _useSoftwareDecoding
                                      ? 'Modo: Software (AC3)'
                                      : 'Modo: Hardware',
                                ),
                                onPressed: _toggleDecoderMode,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.skip_previous),
                                label: const Text('Canal Anterior'),
                                onPressed: _currentIndex > 0
                                    ? () => _changeChannel(_currentIndex - 1)
                                    : null,
                              ),
                              const SizedBox(width: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.skip_next),
                                label: const Text('Siguiente Canal'),
                                onPressed:
                                    _currentIndex < widget.channels.length - 1
                                        ? () => _changeChannel(_currentIndex + 1)
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
