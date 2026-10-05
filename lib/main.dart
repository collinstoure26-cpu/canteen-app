import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() => runApp(const CanteenApp());

const baseUrl = 'https://canteen-backend-4hs1.onrender.com';
List<Map<String, dynamic>> menu = [];

Future<dynamic> api(String method, String path,
    [Map<String, dynamic>? body]) async {
  final uri = Uri.parse('$baseUrl$path');
  final headers = {'Content-Type': 'application/json'};
  http.Response r;
  if (method == 'GET') {
    r = await http.get(uri);
  } else if (method == 'POST') {
    r = await http.post(uri, headers: headers, body: jsonEncode(body));
  } else if (method == 'PUT') {
    r = await http.put(uri, headers: headers, body: jsonEncode(body));
  } else if (method == 'DELETE') {
    r = await http.delete(uri, headers: headers);
  } else {
    r = await http.patch(uri, headers: headers, body: jsonEncode(body));
  }
  dynamic data;
  try {
    data = jsonDecode(r.body);
  } catch (_) {
    throw 'Server error (${r.statusCode})';
  }
  if (r.statusCode >= 400) throw '${data['error'] ?? 'Request failed'}';
  return data;
}

String errText(Object e) =>
    e is String ? e : 'Cannot reach the server. Is it running?';

double priceOf(String name) =>
    (menu.firstWhere((m) => m['name'] == name)['price'] as num).toDouble();

String summaryOf(Map o) =>
    (o['items'] as List).map((i) => '${i['qty']}x ${i['name']}').join(', ');

String shortId(Map o) {
  final id = o['_id'] as String;
  return id.substring(id.length - 4);
}

void logout(BuildContext context) => Navigator.pushReplacement(
    context, MaterialPageRoute(builder: (_) => const LoginScreen()));

void snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Widget foodImage(dynamic image, {double size = 56}) {
  if (image is String && image.isNotEmpty) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(base64Decode(image),
            width: size, height: size, fit: BoxFit.cover),
      );
    } catch (_) {}
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
        color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.fastfood, color: Colors.orange),
  );
}

class CanteenApp extends StatelessWidget {
  const CanteenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Campus Canteen',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
        home: const LoginScreen(),
      );
}

// ---------- LOGIN ----------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> submit(bool register) async {
    setState(() {
      error = null;
      busy = true;
    });
    try {
      final body = {'email': email.text.trim(), 'password': password.text};
      if (register) await api('POST', '/register', body);
      final u = await api('POST', '/login', body);
      menu = List<Map<String, dynamic>>.from(await api('GET', '/menu'));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => u['role'] == 'staff'
              ? const StaffScreen()
              : MenuScreen(email: u['email']),
        ),
      );
      return;
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant, size: 64, color: Colors.orange),
                const Text('Campus Canteen',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                    controller: email,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password', border: OutlineInputBorder())),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: busy ? null : () => submit(false),
                        child: Text(busy ? 'Please wait...' : 'Log in'))),
                TextButton(
                    onPressed: busy ? null : () => submit(true),
                    child: const Text('Create student account')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- STUDENT: MENU ----------
class MenuScreen extends StatefulWidget {
  final String email;
  const MenuScreen({super.key, required this.email});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final cart = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final count = cart.values.fold(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Canteen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Orders',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MyOrdersScreen(email: widget.email))),
          ),
          TextButton.icon(
            icon: const Icon(Icons.shopping_cart),
            label: Text('Cart ($count)'),
            onPressed: () async {
              final placed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        CartScreen(cart: cart, email: widget.email)),
              );
              if (placed == true) cart.clear();
              setState(() {});
            },
          ),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () => logout(context)),
        ],
      ),
      body: ListView(
        children: menu.map((item) {
          final name = item['name'] as String;
          return ListTile(
            leading: foodImage(item['image']),
            title: Text(name),
            subtitle:
                Text('\$${(item['price'] as num).toStringAsFixed(2)}'),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () =>
                  setState(() => cart[name] = (cart[name] ?? 0) + 1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------- STUDENT: CART ----------
class CartScreen extends StatefulWidget {
  final Map<String, int> cart;
  final String email;
  const CartScreen({super.key, required this.cart, required this.email});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String pickup = '12:30 PM';
  final times = ['12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM'];
  bool busy = false;

  double get total =>
      widget.cart.entries.fold(0.0, (s, e) => s + priceOf(e.key) * e.value);

  void change(String name, int delta) {
    setState(() {
      final q = (widget.cart[name] ?? 0) + delta;
      if (q <= 0) {
        widget.cart.remove(name);
      } else {
        widget.cart[name] = q;
      }
    });
  }

  Future<void> placeOrder() async {
    setState(() => busy = true);
    try {
      final items = widget.cart.entries
          .map((e) =>
              {'name': e.key, 'qty': e.value, 'price': priceOf(e.key)})
          .toList();
      final o = await api('POST', '/orders', {
        'student': widget.email,
        'items': items,
        'pickup': pickup,
        'total': total,
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Order #${shortId(o)} placed'),
          content: Text(
              'Pickup: $pickup\nTotal: \$${total.toStringAsFixed(2)}\nStatus: Placed'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'))
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        snack(context, errText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: widget.cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: widget.cart.entries.map((e) {
                      return ListTile(
                        leading: foodImage(menu.firstWhere(
                            (m) => m['name'] == e.key)['image']),
                        title: Text(e.key),
                        subtitle: Text(
                            '\$${(priceOf(e.key) * e.value).toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => change(e.key, -1)),
                            Text('${e.value}'),
                            IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => change(e.key, 1)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pickup time'),
                          DropdownButton<String>(
                            value: pickup,
                            items: times
                                .map((t) =>
                                    DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => pickup = v!),
                          ),
                        ],
                      ),
                      Text('Total: \$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: busy ? null : placeOrder,
                            child: Text(busy ? 'Placing...' : 'Place Order')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------- STUDENT: MY ORDERS ----------
class MyOrdersScreen extends StatefulWidget {
  final String email;
  const MyOrdersScreen({super.key, required this.email});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<dynamic> future;

  Future<dynamic> load() => api(
      'GET', '/orders?student=${Uri.encodeQueryComponent(widget.email)}');

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders'), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => future = load())),
      ]),
      body: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(errText(snap.error!)));
          }
          final list = snap.data as List;
          if (list.isEmpty) return const Center(child: Text('No orders yet'));
          return ListView(
            children: list
                .map((o) => Card(
                      child: ListTile(
                        title: Text('Order #${shortId(o)} - ${o['status']}'),
                        subtitle: Text(
                            '${summaryOf(o)}\nPickup ${o['pickup']} - \$${(o['total'] as num).toStringAsFixed(2)}'),
                        isThreeLine: true,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

// ---------- STAFF ----------
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<dynamic> future;

  Future<dynamic> load() => api('GET', '/orders');

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff - Orders'),
        actions: [
          IconButton(
              icon: const Icon(Icons.restaurant_menu),
              tooltip: 'Manage menu',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageMenuScreen()))),
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => future = load())),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () => logout(context)),
        ],
      ),
      body: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(errText(snap.error!)));
          }
          final list = snap.data as List;
          if (list.isEmpty) return const Center(child: Text('No orders yet'));
          return ListView(
            children: list.map((o) {
              return Card(
                child: ListTile(
                  title: Text('Order #${shortId(o)} - ${o['status']}'),
                  subtitle: Text('${summaryOf(o)}\nPickup ${o['pickup']}'),
                  isThreeLine: true,
                  trailing: o['status'] == 'Ready'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : FilledButton(
                          onPressed: () async {
                            final next =
                                o['status'] == 'Placed' ? 'Preparing' : 'Ready';
                            try {
                              await api('PATCH', '/orders/${o['_id']}',
                                  {'status': next});
                              setState(() => future = load());
                            } catch (e) {
                              if (mounted) snack(context, errText(e));
                            }
                          },
                          child: Text(o['status'] == 'Placed'
                              ? 'Start'
                              : 'Mark Ready'),
                        ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ---------- STAFF: MANAGE MENU ----------
class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});
  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  Future<void> reload() async {
    menu = List<Map<String, dynamic>>.from(await api('GET', '/menu'));
    if (mounted) setState(() {});
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name'] ?? '');
    final price =
        TextEditingController(text: item == null ? '' : '${item['price']}');
    String? image = item?['image'];
    String? err;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(item == null ? 'Add item' : 'Edit item'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              foodImage(image, size: 120),
              TextButton.icon(
                icon: const Icon(Icons.photo),
                label: Text(image == null ? 'Add photo' : 'Change photo'),
                onPressed: () async {
                  final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 600,
                      maxHeight: 600,
                      imageQuality: 70);
                  if (f == null) return;
                  final bytes = await f.readAsBytes();
                  setD(() {
                    if (bytes.length > 3000000) {
                      err = 'Photo too large, pick a smaller one';
                    } else {
                      err = null;
                      image = base64Encode(bytes);
                    }
                  });
                },
              ),
              if (err != null)
                Text(err!, style: const TextStyle(color: Colors.red)),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final p = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || p == null) {
      if (mounted) snack(context, 'Enter a name and a valid price');
      return;
    }
    try {
      final body = {'name': name.text.trim(), 'price': p, 'image': image};
      if (item == null) {
        await api('POST', '/menu', body);
      } else {
        await api('PUT', '/menu/${item['_id']}', body);
      }
      await reload();
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api('DELETE', '/menu/${item['_id']}');
      await reload();
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Menu')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => edit(), child: const Icon(Icons.add)),
      body: ListView(
        children: menu
            .map((item) => ListTile(
                  leading: foodImage(item['image']),
                  title: Text(item['name']),
                  subtitle:
                      Text('\$${(item['price'] as num).toStringAsFixed(2)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => edit(item)),
                    IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => remove(item)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}
