import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _api = 'https://api.frankfurter.dev/v1';

void main() => runApp(const CurrencyApp());

class CurrencyApp extends StatelessWidget {
  const CurrencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Currency Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final _amountCtrl = TextEditingController(text: '1');
  Map<String, String> _currencies = {};
  String _from = 'USD';
  String _to = 'THB';
  double? _result;
  double? _rate;
  String? _date;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$_api/currencies'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('โหลดรายชื่อสกุลเงินไม่สำเร็จ (${res.statusCode})');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _currencies = data.map((k, v) => MapEntry(k, v as String));
      await _convert();
    } catch (e) {
      setState(() {
        _error = 'เชื่อมต่อไม่ได้ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null) {
      setState(() {
        _error = 'กรุณากรอกจำนวนเงินเป็นตัวเลข';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_from == _to) {
        setState(() {
          _rate = 1;
          _result = amount;
          _loading = false;
        });
        return;
      }
      final res = await http
          .get(Uri.parse('$_api/latest?base=$_from&symbols=$_to'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('ดึงอัตราแลกเปลี่ยนไม่สำเร็จ (${res.statusCode})');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rate = (data['rates'][_to] as num).toDouble();
      setState(() {
        _rate = rate;
        _result = amount * rate;
        _date = data['date'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาด: $e';
        _loading = false;
      });
    }
  }

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
    });
    _convert();
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '$intPart.${parts[1]}';
  }

  Widget _dropdown(String value, ValueChanged<String> onChanged) {
    final codes = _currencies.keys.toList()..sort();
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: codes
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text('$c – ${_currencies[c]}', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
          _convert();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh),
            onPressed: _currencies.isEmpty ? _init : _convert,
          ),
        ],
      ),
      body: _currencies.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : _currencies.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'เกิดข้อผิดพลาด', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _init, child: const Text('ลองใหม่')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'จำนวนเงิน',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _convert(),
                    ),
                    const SizedBox(height: 16),
                    _dropdown(_from, (v) => setState(() => _from = v)),
                    Center(
                      child: IconButton(
                        tooltip: 'สลับสกุลเงิน',
                        icon: const Icon(Icons.swap_vert, size: 32),
                        onPressed: _swap,
                      ),
                    ),
                    _dropdown(_to, (v) => setState(() => _to = v)),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Text(_error!, style: TextStyle(color: cs.error)),
                    if (_error == null)
                      Card(
                        color: cs.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _loading && _result == null
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    Text(
                                      _result == null
                                          ? '-'
                                          : '${_fmt(_result!)} $_to',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_rate != null)
                                      Text('1 $_from = ${_rate!.toStringAsFixed(4)} $_to'),
                                    if (_date != null)
                                      Text('อัตราแลกเปลี่ยนวันที่ $_date',
                                          style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'ข้อมูลจาก Frankfurter API (European Central Bank)',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
    );
  }
}