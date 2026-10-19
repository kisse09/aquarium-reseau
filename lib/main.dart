import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ces deux valeurs sont publiques : la sécurité est assurée par les règles
// de la base de données (Row Level Security) créées dans Supabase.
const supabaseUrl = 'https://hjqqmxbkmtvwzwtcbyet.supabase.co';
const supabaseKey = 'sb_publishable_ioELBHQCDGue089RSU7I0Q_psv9287F';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  } catch (e, s) {
    runApp(StartupErrorApp('$e\n\n$s'));
    return;
  }
  runApp(const AquariumApp());
}

class StartupErrorApp extends StatelessWidget {
  final String message;
  const StartupErrorApp(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Erreur au démarrage')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(message),
        ),
      ),
    );
  }
}

final db = Supabase.instance.client;

String get myId => db.auth.currentUser!.id;

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

const river = Color(0xFF0E5A5F);
const ember = Color(0xFFE2582D);

class AquariumApp extends StatelessWidget {
  const AquariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aquarium Réseau',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: river,
          secondary: ember,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Connexion
// ---------------------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        return db.auth.currentSession == null
            ? const LoginPage()
            : const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _signup = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (_signup) {
        final name = _name.text.trim().isEmpty ? 'Voisin' : _name.text.trim();
        final res = await db.auth.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          data: {'display_name': name},
        );
        if (res.session == null && mounted) {
          toast(context,
              'Compte créé. Confirme ton e-mail, puis connecte-toi.');
        }
      } else {
        await db.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, 'Erreur : $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const Icon(Icons.set_meal, size: 64, color: river),
                const SizedBox(height: 12),
                Text('Aquarium Réseau',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Les voisins d\'Odza, près de toi.'),
                const SizedBox(height: 28),
                if (_signup) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ton prénom'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Mot de passe (6 caractères minimum)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_signup ? 'Créer mon compte' : 'Me connecter'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _signup = !_signup),
                  child: Text(_signup
                      ? 'J\'ai déjà un compte'
                      : 'Je n\'ai pas encore de compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation principale
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = <Widget>[
    FeedPage(),
    NeighborsPage(),
    MessagesPage(),
    AquariumPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Quartier'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Voisins'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Aquarium'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

const _radiusChoices = [500, 1000, 2000, 5000];

String _distanceLabel(dynamic meters) {
  final m = (meters as num).round();
  if (m < 50) return 'à moins de 50 m';
  if (m >= 1000) return 'à ${(m / 1000).toStringAsFixed(1)} km';
  return 'à $m m';
}

// ---------------------------------------------------------------------------
// Fil du quartier
// ---------------------------------------------------------------------------

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _text = TextEditingController();
  int _radius = 2000;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final res = await db.rpc('nearby_posts', params: {'radius_m': _radius});
    return res as List<dynamic>;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _post() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    try {
      await db.from('posts').insert({'author_id': myId, 'content': t});
      _text.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _reload();
    } catch (e) {
      if (mounted) toast(context, 'Publication impossible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon quartier')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Dis quelque chose à tes voisins',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _post, child: const Text('Publier')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text('Rayon :'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _radius,
                  items: [
                    for (final r in _radiusChoices)
                      DropdownMenuItem(
                        value: r,
                        child: Text(r >= 1000 ? '${r ~/ 1000} km' : '$r m'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    _radius = v;
                    _reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          'Impossible de charger le fil. Vérifie ta connexion.\n${snap.error}'),
                    ),
                  );
                }
                final posts = snap.data ?? [];
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aucune publication près de toi pour le moment. '
                            'Dans l\'onglet Profil, active le partage de ta position '
                            'et mets-la à jour, puis publie le premier message.',
                          ),
                        ),
                      for (final p in posts)
                        Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text('${p['author_name']}'),
                            subtitle: Text('${p['content']}'),
                            trailing: Text(_distanceLabel(p['distance_m'])),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voisins
// ---------------------------------------------------------------------------

class NeighborsPage extends StatefulWidget {
  const NeighborsPage({super.key});

  @override
  State<NeighborsPage> createState() => _NeighborsPageState();
}

class _NeighborsPageState extends State<NeighborsPage> {
  int _radius = 2000;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    final res =
        await db.rpc('nearby_profiles', params: {'radius_m': _radius});
    return res as List<dynamic>;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voisins'),
        actions: [
          DropdownButton<int>(
            value: _radius,
            underline: const SizedBox(),
            items: [
              for (final r in _radiusChoices)
                DropdownMenuItem(
                  value: r,
                  child: Text(r >= 1000 ? '${r ~/ 1000} km' : '$r m'),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              _radius = v;
              _reload();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Impossible de charger les voisins.\n${snap.error}'),
            ));
          }
          final people = snap.data ?? [];
          if (people.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Personne à proximité pour l\'instant. '
                  'Mets ta position à jour dans l\'onglet Profil, '
                  'ou agrandis le rayon.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final p in people)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${p['display_name']}'),
                  subtitle: Text(
                      '${p['quartier'] ?? 'Quartier non précisé'} · ${_distanceLabel(p['distance_m'])}'),
                  trailing: const Icon(Icons.chat_bubble_outline),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatPage(
                      otherId: p['id'] as String,
                      otherName: '${p['display_name']}',
                    ),
                  )),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final msgs = await db
        .from('messages')
        .select()
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false)
        .limit(200);
    final last = <String, Map<String, dynamic>>{};
    for (final m in msgs) {
      final other = (m['sender_id'] == myId ? m['receiver_id'] : m['sender_id'])
          as String;
      last.putIfAbsent(other, () => m);
    }
    if (last.isEmpty) return [];
    final profs = await db
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', last.keys.toList());
    final names = <String, String>{
      for (final p in profs) (p['id'] as String): '${p['display_name']}',
    };
    return [
      for (final e in last.entries)
        <String, dynamic>{
          'other_id': e.key,
          'name': names[e.key] ?? 'Voisin',
          'content': e.value['content'],
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Impossible de charger les messages.\n${snap.error}'),
            ));
          }
          final convs = snap.data ?? [];
          if (convs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune conversation. Ouvre l\'onglet Voisins '
                  'et écris à quelqu\'un près de toi.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              for (final c in convs)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${c['name']}'),
                  subtitle: Text(
                    '${c['content']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatPage(
                        otherId: c['other_id'] as String,
                        otherName: '${c['name']}',
                      ),
                    ));
                    if (mounted) setState(() => _future = _load());
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String otherId;
  final String otherName;

  const ChatPage({super.key, required this.otherId, required this.otherName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _msgs = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final o = widget.otherId;
      final res = await db
          .from('messages')
          .select()
          .or('and(sender_id.eq.$myId,receiver_id.eq.$o),and(sender_id.eq.$o,receiver_id.eq.$myId)')
          .order('created_at', ascending: true);
      if (mounted) setState(() => _msgs = res);
    } catch (_) {
      // On réessaiera au prochain passage.
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    try {
      await db.from('messages').insert({
        'sender_id': myId,
        'receiver_id': widget.otherId,
        'content': t,
      });
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Message non envoyé : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (context, i) {
                final m = _msgs[i];
                final mine = m['sender_id'] == myId;
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('${m['content']}'),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration:
                          const InputDecoration(hintText: 'Ton message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    color: river,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page du restaurant
// ---------------------------------------------------------------------------

class AquariumPage extends StatelessWidget {
  const AquariumPage({super.key});

  Widget _section(BuildContext context, String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aquarium')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Restaurant-bar Aquarium',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Le poisson d\'eau douce, braisé comme on l\'aime.'),
          _section(context, 'Où nous trouver', const [
            'Odza, entrée Adventiste, à 200 m de l\'entrée.',
          ]),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.phone, size: 18, color: ember),
              SizedBox(width: 8),
              SelectableText('698 885 322'),
            ],
          ),
          _section(context, 'Nos spécialités', const [
            'Poisson d\'eau douce braisé',
            'Ndomba de silure',
            'Brochettes de viande ou de poulet',
            'Poulet braisé, coupé en quarts',
          ]),
          _section(context, 'Menu du jour', const [
            'Bouillon de bœuf',
            'Porc',
            'Viande de brousse : vipère, porc-épic et autres',
          ]),
          _section(context, 'Boissons', const [
            'Bières, jus, whisky, vin rouge, vin blanc, mouscato, baileys '
                'et toutes les boissons vendues au Cameroun.',
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _quartier = TextEditingController();
  bool _share = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await db.from('profiles').select().eq('id', myId).single();
      _name.text = '${p['display_name'] ?? ''}';
      _quartier.text = '${p['quartier'] ?? ''}';
      _share = p['share_location'] == true;
    } catch (_) {
      // Le profil sera rempli à la prochaine ouverture.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await db.from('profiles').update({
        'display_name':
            _name.text.trim().isEmpty ? 'Voisin' : _name.text.trim(),
        'quartier': _quartier.text.trim().isEmpty ? null : _quartier.text.trim(),
        'share_location': _share,
      }).eq('id', myId);
      if (mounted) toast(context, 'Profil enregistré');
    } catch (e) {
      if (mounted) toast(context, 'Enregistrement impossible : $e');
    }
  }

  Future<void> _updateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          toast(context, 'Active la localisation (GPS) de ton téléphone.');
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          toast(context,
              'Autorise la localisation pour cette application dans les réglages du téléphone.');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await db.from('profile_locations').upsert({
        'user_id': myId,
        'location': 'SRID=4326;POINT(${pos.longitude} ${pos.latitude})',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) toast(context, 'Position mise à jour');
    } catch (e) {
      if (mounted) toast(context, 'Position non mise à jour : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quartier,
                  decoration: const InputDecoration(
                      labelText: 'Quartier (par exemple Odza)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Partager ma position avec le quartier'),
                  subtitle: const Text(
                      'Les autres voient seulement une distance approximative, jamais ta position exacte.'),
                  value: _share,
                  onChanged: (v) => setState(() => _share = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: _save, child: const Text('Enregistrer')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _updateLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Mettre à jour ma position'),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => db.auth.signOut(),
                  child: const Text('Me déconnecter'),
                ),
              ],
            ),
    );
  }
}
