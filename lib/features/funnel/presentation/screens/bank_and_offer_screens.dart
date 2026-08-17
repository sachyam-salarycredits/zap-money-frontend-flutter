import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/screen_status_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_widgets.dart';
import '../../../../core/widgets/funnel_scaffold.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../dashboard/data/home_repository.dart';

/// RN bankDetails / bankStatement title: Student → Bank Details, else Salary Account.
String _bankAccountDetailsTitle(String userType) {
  return userType.toLowerCase() == 'student'
      ? 'Bank\nDetails'
      : 'Salary\nAccount\nDetails';
}

/// RN `scenes/bankDetails` — name (read-only), IFSC lookup → bank/branch, account.
class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _customerName = TextEditingController();
  final _ifsc = TextEditingController();
  final _account = TextEditingController();
  final _bankName = TextEditingController();
  final _branch = TextEditingController();

  bool _lookingUpIfsc = false;
  String? _finbitCode;

  String _userType = 'Salaried';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCustomerName();
      final type = await ref
          .read(sessionStorageProvider)
          .read(StorageKeys.userType);
      if (mounted) {
        setState(() {
          _userType = (type ?? 'Salaried').replaceAll('"', '');
        });
      }
    });
  }

  @override
  void dispose() {
    _customerName.dispose();
    _ifsc.dispose();
    _account.dispose();
    _bankName.dispose();
    _branch.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _customerName.text.trim().isNotEmpty &&
        _ifsc.text.trim().length == 11 &&
        _account.text.trim().length >= 8 &&
        _bankName.text.trim().isNotEmpty &&
        _branch.text.trim().isNotEmpty;
  }

  Future<void> _loadCustomerName() async {
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) return;

      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getCustomerInfo,
            data: {'customer_id': customerId},
            options: Options(contentType: Headers.jsonContentType),
          );
      final root = response.data;
      // RN: response.data[0].first_name / last_name
      Map<String, dynamic>? row;
      if (root is List && root.isNotEmpty && root.first is Map) {
        row = Map<String, dynamic>.from(root.first as Map);
      } else if (root is Map) {
        final data = root['data'];
        if (data is List && data.isNotEmpty && data.first is Map) {
          row = Map<String, dynamic>.from(data.first as Map);
        } else if (data is Map) {
          row = Map<String, dynamic>.from(data);
        } else {
          row = Map<String, dynamic>.from(root);
        }
      }
      if (row == null) return;
      final first =
          row['first_name']?.toString() ?? row['firstName']?.toString() ?? '';
      final last =
          row['last_name']?.toString() ?? row['lastName']?.toString() ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty && mounted) {
        setState(() => _customerName.text = name.toUpperCase());
      }
    } catch (_) {
      // Name stays empty; user still sees the field.
    }
  }

  Future<void> _onIfscChanged(String raw) async {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (value != _ifsc.text) {
      _ifsc.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {});

    if (value.length != 11) {
      setState(() {
        _bankName.clear();
        _branch.clear();
        _finbitCode = null;
      });
      return;
    }

    setState(() => _lookingUpIfsc = true);
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getIfscInfo,
            data: {'ifsc': value},
            options: Options(contentType: Headers.jsonContentType),
          );
      final data = response.data;
      final list = data is Map ? data['ResponseData'] : null;
      if (list is List && list.isNotEmpty && list.first is Map) {
        final row = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _bankName.text = row['bankname']?.toString() ?? '';
          _branch.text = row['branch']?.toString() ?? '';
          _finbitCode = row['FINBITCODE']?.toString();
        });
      } else {
        setState(() {
          _bankName.clear();
          _branch.clear();
          _finbitCode = null;
        });
        _toast('Invalid IFSC code');
      }
    } catch (_) {
      setState(() {
        _bankName.clear();
        _branch.clear();
      });
      _toast('Could not look up IFSC');
    } finally {
      if (mounted) setState(() => _lookingUpIfsc = false);
    }
  }

  Future<void> _submit() async {
    final ifsc = _ifsc.text.trim().toUpperCase();
    final account = _account.text.trim();
    final bank = _bankName.text.trim();
    final branch = _branch.text.trim();
    final name = _customerName.text.trim();

    if (ifsc.length < 11) {
      _toast('Please enter ifsc code');
      return;
    }
    if (account.length < 9) {
      _toast('Please enter account number');
      return;
    }
    if (bank.isEmpty) {
      _toast('Please enter bank name');
      return;
    }
    if (branch.isEmpty) {
      _toast('Please enter branch');
      return;
    }
    if (name.isEmpty) {
      _toast('Customer name missing');
      return;
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      final deviceId = (await storage.read(
        StorageKeys.deviceId,
      ))?.replaceAll('"', '');

      // StoreBankInfo overwrites Enach_Amount with request value (null if
      // omitted) — preserve any amount already set after offer origination.
      String? existingEnachAmount;
      try {
        final bankRes = await ref
            .read(dioClientProvider)
            .dio
            .post(
              ApiEndpoints.getBankAccountInformation,
              data: {
                'customer_id': int.tryParse(customerId ?? '') ?? customerId,
              },
              options: Options(contentType: Headers.jsonContentType),
            );
        final bankData = bankRes.data;
        Map? row;
        if (bankData is List && bankData.isNotEmpty && bankData.first is Map) {
          row = bankData.first as Map;
        }
        final rawAmt = row?['enach_amount'];
        final parsed = rawAmt == null
            ? null
            : double.tryParse(rawAmt.toString());
        if (parsed != null && parsed > 0) {
          existingEnachAmount = parsed.toString();
        }
      } catch (_) {}

      // RN getBankDetails → StoreBankInfo (Bearer via useBearer)
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.storeBankInfo,
            data: {
              'deviceId': deviceId,
              'customer_name': name,
              'customer_id': int.tryParse(customerId ?? '') ?? customerId,
              'sf_record_id': '',
              'ifsc_code': ifsc,
              'bank_account_number': account,
              'bank_name': bank,
              'branch_name': branch,
              if (existingEnachAmount != null)
                'enach_amount': existingEnachAmount,
            },
            options: Options(
              contentType: Headers.jsonContentType,
              extra: {'useBearer': true},
            ),
          );

      final data = response.data;
      final status = data is Map ? data['status'] : null;
      if (status != 200 && status != '200') {
        final msg = data is Map
            ? (data['msg'] ?? data['message'])?.toString()
            : null;
        _toast(msg ?? 'Could not save bank details');
        return;
      }

      await ref.read(screenStatusServiceProvider).completeBank();
      if (!mounted) return;
      // RN → ScreenName.bankStatement (title depends on Student vs Salaried)
      context.go(
        AppRoutes.bankStatement,
        extra: {'bankcode': _finbitCode, 'bankName': bank},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map
          ? (data['msg'] ?? data['message'])?.toString()
          : null;
      _toast(msg ?? 'Bank account could not be verified. Please try again.');
    } catch (_) {
      _toast('Could not save bank details');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);

    return FunnelScaffold(
      title: _bankAccountDetailsTitle(_userType),
      totalSteps: 3,
      activeStep: 2,
      heroAsset: 'assets/images/bankdoc.png',
      heroHeight: 110,
      bottom: ZapSubmitButton(
        title: 'Submit',
        disabled: !_canSubmit || loading || _lookingUpIfsc,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('Name as per Bank Account*'),
          _field(_customerName, 'Enter Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Bank IFSC Code*'),
          _field(
            _ifsc,
            'Enter IFSC Code',
            maxLength: 11,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: _onIfscChanged,
            suffix: _lookingUpIfsc
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _label('Account Number*'),
          _field(
            _account,
            'Enter Account Number',
            keyboard: TextInputType.number,
            maxLength: 30,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _label('Bank Name*'),
          _field(_bankName, 'Enter Bank Name', readOnly: true, muted: true),
          const SizedBox(height: 16),
          _label('Bank Branch*'),
          _field(_branch, 'Enter Branch', readOnly: true, muted: true),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.body(size: 12, color: AppColors.muted),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    bool muted = false,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: c,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      keyboardType: keyboard,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: AppTypography.body(
        size: 16,
        color: muted ? AppColors.muted : AppColors.white,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFF2A0A5C),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class BankStatementScreen extends ConsumerStatefulWidget {
  const BankStatementScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<BankStatementScreen> createState() =>
      _BankStatementScreenState();
}

class _PickedPdf {
  const _PickedPdf({
    required this.path,
    required this.name,
    required this.mime,
  });

  final String path;
  final String name;
  final String mime;
}

class _BankStatementScreenState extends ConsumerState<BankStatementScreen> {
  /// RN: Monthly vs Single File
  bool _monthly = true;
  _PickedPdf? _month1;
  _PickedPdf? _month2;
  _PickedPdf? _month3;
  _PickedPdf? _singleFile;
  final _password = TextEditingController();
  String _userType = 'Salaried';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final type = await ref
          .read(sessionStorageProvider)
          .read(StorageKeys.userType);
      if (!mounted) return;
      setState(() {
        _userType = (type ?? 'Salaried').replaceAll('"', '');
      });
    });
  }

  String? get _bankcode {
    final args = widget.args;
    if (args == null) return null;
    final nested = args['bankDetails'];
    if (nested is Map) return nested['bankcode']?.toString();
    return args['bankcode']?.toString();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_monthly) {
      return _month1 != null && _month2 != null && _month3 != null;
    }
    return _singleFile != null;
  }

  Future<void> _pickPdf(void Function(_PickedPdf file) assign) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null || path.isEmpty) {
        _toast('Could not read selected file');
        return;
      }
      final name = file.name;
      if (!name.toLowerCase().endsWith('.pdf') &&
          (file.extension?.toLowerCase() != 'pdf')) {
        _toast('Please Select pdf file only');
        return;
      }
      // RN: 3MB limit
      if (file.size > 3000000) {
        _toast('File size exceeds the limit 3MB');
        return;
      }
      setState(
        () => assign(
          _PickedPdf(
            path: path,
            name: name.isEmpty ? 'statement.pdf' : name,
            mime: 'application/pdf',
          ),
        ),
      );
    } catch (_) {
      _toast('Could not open file picker. Please try again.');
    }
  }

  Future<void> _completeAndContinue() async {
    if (!_canSubmit) {
      _toast('Please upload bank statement PDF(s)');
      return;
    }
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      final sfCustomerId = (await storage.read(
        StorageKeys.sfCustomerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        _toast('Missing customer id — please re-login');
        return;
      }
      final bankcode = _bankcode ?? '';
      final password = _password.text.trim();

      // RN uploadBankStatement → multipart /uploadFinbitBankStatement
      final map = <String, dynamic>{
        'customerId': customerId,
        'sf_customerId': sfCustomerId ?? '',
        'isMultipleStmt': _monthly ? 'True' : 'False',
      };

      Future<void> appendStmt({
        required String index,
        required _PickedPdf pdf,
        required String passwordKey,
      }) async {
        map['bankStmt_$index'] = await MultipartFile.fromFile(
          pdf.path,
          filename: pdf.name,
        );
        map['accountType_$index'] = 'SAVING';
        map['bankCode_$index'] = bankcode;
        if (password.isNotEmpty) {
          map[passwordKey] = password;
        }
      }

      if (_monthly) {
        await appendStmt(index: '1', pdf: _month1!, passwordKey: 'password_1');
        await appendStmt(index: '2', pdf: _month2!, passwordKey: 'password_2');
        await appendStmt(index: '3', pdf: _month3!, passwordKey: 'password_3');
      } else {
        await appendStmt(
          index: '1',
          pdf: _singleFile!,
          passwordKey: 'password_1',
        );
      }

      final form = FormData.fromMap(map);
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.uploadFinbitBankStatement,
            data: form,
            options: Options(
              sendTimeout: const Duration(minutes: 2),
              receiveTimeout: const Duration(minutes: 2),
            ),
          );

      final data = response.data;
      final status = data is Map ? data['Status'] ?? data['status'] : null;
      if (status == 200 || status == '200') {
        await ref.read(screenStatusServiceProvider).completeBank();
        await ref.read(screenStatusServiceProvider).completeFinbit();
        if (mounted) context.go(AppRoutes.residenceAddress);
        return;
      }
      final err = data is Map
          ? (data['error'] ?? data['msg'] ?? data['message'])?.toString()
          : null;
      _toast(err ?? 'Bank statement upload failed');
    } on DioException catch (e) {
      final data = e.response?.data;
      final err = data is Map
          ? (data['error'] ?? data['msg'] ?? data['message'])?.toString()
          : null;
      _toast(err ?? 'Bank statement upload failed');
    } catch (_) {
      _toast('Could not upload bank statement');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(globalLoadingProvider);
    final bankName =
        widget.args?['bankName']?.toString() ??
        (widget.args?['bankDetails'] is Map
            ? (widget.args!['bankDetails'] as Map)['bankName']?.toString()
            : null);

    return FunnelScaffold(
      title: _bankAccountDetailsTitle(_userType),
      totalSteps: 3,
      activeStep: 3,
      heroAsset: 'assets/images/bankdoc.png',
      heroHeight: 110,
      bottom: ZapSubmitButton(
        title: _monthly ? 'Continue' : 'Submit',
        disabled: !_canSubmit || loading,
        onPressed: _completeAndContinue,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (bankName != null && bankName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                bankName,
                style: AppTypography.body(size: 13, color: AppColors.muted),
              ),
            ),
          ZapSubmitButton(
            title: 'Login to your Bank Account',
            onPressed: () {
              context.push(
                AppRoutes.finbit,
                extra: {
                  'bankDetails': {'bankcode': _bankcode, 'bankName': bankName},
                  'bankcode': _bankcode,
                  'bankName': bankName,
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Center(child: Text('OR', style: AppTypography.body(size: 15))),
          const SizedBox(height: 16),
          Text(
            'Upload your Bank Statement as (PDF Only)',
            style: AppTypography.body(size: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _modeChip('Monthly', _monthly, () {
                setState(() {
                  _monthly = true;
                  _singleFile = null;
                });
              }),
              const SizedBox(width: 16),
              _modeChip('Single File', !_monthly, () {
                setState(() {
                  _monthly = false;
                  _month1 = null;
                  _month2 = null;
                  _month3 = null;
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          if (_monthly)
            Row(
              children: [
                Expanded(
                  child: _pdfTile(
                    label: 'Month 1',
                    file: _month1,
                    onPick: () => _pickPdf((p) => _month1 = p),
                    onClear: () => setState(() => _month1 = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pdfTile(
                    label: 'Month 2',
                    file: _month2,
                    onPick: () => _pickPdf((p) => _month2 = p),
                    onClear: () => setState(() => _month2 = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pdfTile(
                    label: 'Month 3',
                    file: _month3,
                    onPick: () => _pickPdf((p) => _month3 = p),
                    onClear: () => setState(() => _month3 = null),
                  ),
                ),
              ],
            )
          else
            _pdfTile(
              label: 'Upload for PDF',
              file: _singleFile,
              tall: true,
              onPick: () => _pickPdf((p) => _singleFile = p),
              onClear: () => setState(() => _singleFile = null),
            ),
          const SizedBox(height: 16),
          Text(
            'File Password (If Any)',
            style: AppTypography.body(size: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _password,
            obscureText: true,
            cursorColor: Colors.white,
            style: AppTypography.body(size: 16),
            decoration: InputDecoration(
              hintText: 'Enter your password ',
              hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
              filled: true,
              fillColor: const Color(0xFF2A0A5C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.accentMint : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.body(size: 14)),
        ],
      ),
    );
  }

  Widget _pdfTile({
    required String label,
    required _PickedPdf? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
    bool tall = false,
  }) {
    final path = file?.path;
    return AspectRatio(
      aspectRatio: tall ? 2.2 : 0.85,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3E1982),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: path == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Upload for',
                      style: AppTypography.body(
                        size: 10,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Icon(
                      Icons.upload,
                      color: Color(0xFFAC9FC6),
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                        size: 11,
                        color: const Color(0xFFAC9FC6),
                      ),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 36,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              file?.name ?? path.split('/').last,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.body(size: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onClear,
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// RN Finbit / net-banking path opened from salary account details.
/// "Login to Net banking" must open Finbit WebView — not skip to residence.
class FinbitScreen extends ConsumerStatefulWidget {
  const FinbitScreen({super.key, this.args});

  final Map<String, dynamic>? args;

  @override
  ConsumerState<FinbitScreen> createState() => _FinbitScreenState();
}

class _FinbitScreenState extends ConsumerState<FinbitScreen> {
  bool _webviewVisible = false;
  String? _finbitUrl;
  WebViewController? _controller;
  var _handlingMessage = false;

  /// RN `AppConstant.INJECTED_JAVASCRIPT` + Flutter channel polyfill.
  static const _injectedJs = '''
(function() {
  if (!window.ReactNativeWebView) {
    window.ReactNativeWebView = {
      postMessage: function(msg) {
        if (window.FinbitBridge && window.FinbitBridge.postMessage) {
          window.FinbitBridge.postMessage(
            typeof msg === 'string' ? msg : JSON.stringify(msg)
          );
        }
      }
    };
  }
  if (window.addEventListener) {
    window.addEventListener("message", handlePostMessage, false);
  } else {
    window.attachEvent("onmessage", handlePostMessage);
  }
  function handlePostMessage(obj) {
    if (obj.data && obj.data != null && obj.data != "") {
      window.ReactNativeWebView.postMessage(
        typeof obj.data === 'string' ? obj.data : JSON.stringify(obj.data)
      );
    }
  }
})();
''';

  String? get _bankcode {
    final args = widget.args;
    if (args == null) return null;
    final nested = args['bankDetails'];
    if (nested is Map) {
      return nested['bankcode']?.toString();
    }
    return args['bankcode']?.toString();
  }

  Future<void> _openNetBanking() async {
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getFinbitUrl,
            data: {'bankcode': _bankcode ?? ''},
            options: Options(contentType: Headers.jsonContentType),
          );
      final root = response.data;
      String? url;
      if (root is Map) {
        final data = root['data'];
        if (data is String) {
          url = data;
        } else if (data is Map) {
          url = data['url']?.toString() ?? data['data']?.toString();
        } else {
          url = root['url']?.toString();
        }
      } else if (root is String) {
        url = root;
      }
      if (url == null || url.isEmpty) {
        _toast('Could not open bank login. Please try again.');
        return;
      }
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'FinbitBridge',
          onMessageReceived: (message) {
            unawaited(_onWebMessage(message.message));
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) async {
              await _controller?.runJavaScript(_injectedJs);
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
      if (!mounted) return;
      setState(() {
        _finbitUrl = url;
        _controller = controller;
        _webviewVisible = true;
      });
    } catch (_) {
      _toast('Could not open bank login. Please try again.');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _onWebMessage(String raw) async {
    if (_handlingMessage) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
      // RN: sometimes double-encoded / nested
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
    } catch (_) {
      return;
    }
    String? accountUid;
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        accountUid = (data.first as Map)['accountUID']?.toString();
      } else if (data is Map) {
        accountUid = data['accountUID']?.toString();
      } else {
        accountUid = decoded['accountUID']?.toString();
      }
    }
    if (accountUid == null || accountUid.isEmpty) return;

    _handlingMessage = true;
    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.finbitBankVerification,
            data: {
              'customerid': int.tryParse(customerId ?? '') ?? customerId,
              'accoundUID': accountUid, // RN typo preserved
            },
            options: Options(contentType: Headers.jsonContentType),
          );
      // RN: complete bank + finbit, then residence
      await ref.read(screenStatusServiceProvider).completeBank();
      await ref.read(screenStatusServiceProvider).completeFinbit();
      if (!mounted) return;
      setState(() => _webviewVisible = false);
      context.go(AppRoutes.residenceAddress);
    } catch (_) {
      _handlingMessage = false;
      _toast('Bank verification failed. Please try again.');
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_webviewVisible && _controller != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _webviewVisible = false),
          ),
          title: Text(
            'Bank login',
            style: AppTypography.headline(
              size: 16,
            ).copyWith(color: Colors.black),
          ),
        ),
        body: WebViewWidget(controller: _controller!),
      );
    }

    return FunnelScaffold(
      title: 'Bank account\nValidation',
      showBack: true,
      totalSteps: 3,
      activeStep: 3,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('Use Net Banking', style: AppTypography.headline(size: 18)),
          const SizedBox(height: 10),
          Text(
            'Login to your Net banking to validate\nyour bank account details',
            style: AppTypography.body(size: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 200,
              child: ZapSubmitButton(
                title: 'Login to Net banking',
                onPressed: _openNetBanking,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: AppColors.muted),
              const SizedBox(width: 10),
              Text(
                'Takes Just 30 Seconds',
                style: AppTypography.body(size: 12, color: AppColors.muted),
              ),
            ],
          ),
          if (_finbitUrl != null) ...[
            const SizedBox(height: 12),
            Text(
              'If the browser closed early, tap Login again.',
              style: AppTypography.body(size: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class ResidenceAddressScreen extends ConsumerStatefulWidget {
  const ResidenceAddressScreen({super.key});

  @override
  ConsumerState<ResidenceAddressScreen> createState() =>
      _ResidenceAddressScreenState();
}

class _ResidenceAddressScreenState
    extends ConsumerState<ResidenceAddressScreen> {
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _locality = TextEditingController();
  final _sublocality = TextEditingController();
  bool _lookingUpPin = false;

  @override
  void dispose() {
    _address.dispose();
    _postal.dispose();
    _city.dispose();
    _state.dispose();
    _locality.dispose();
    _sublocality.dispose();
    super.dispose();
  }

  Future<void> _onPostalChanged(String raw) async {
    final pin = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (pin != _postal.text) {
      _postal.value = TextEditingValue(
        text: pin,
        selection: TextSelection.collapsed(offset: pin.length),
      );
    }
    if (pin.length != 6) return;
    setState(() => _lookingUpPin = true);
    try {
      // RN getAutoFillAddress → monexo addressAutofill/getCity
      final cityRes = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.fetchCity,
            data: FormData.fromMap({'pincode': pin}),
          );
      final cityRoot = cityRes.data;
      if (cityRoot is Map && cityRoot['status_code'] == 200) {
        final result = cityRoot['result'];
        final data = result is Map ? result['data'] : null;
        if (data is Map) {
          final city = data['city']?.toString() ?? '';
          if (city.isNotEmpty) _city.text = city;
        }
      }

      // RN getLocality → first locality as default
      final locRes = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getLocalities,
            data: {'pincode': pin},
            options: Options(contentType: Headers.jsonContentType),
          );
      final locRoot = locRes.data;
      if (locRoot is Map && locRoot['status_code'] == 200) {
        final result = locRoot['result'];
        final list = result is Map ? result['locality'] : null;
        if (list is List && list.isNotEmpty) {
          final first = list.first.toString();
          if (first.isNotEmpty) {
            _locality.text = first;
            final subRes = await ref
                .read(dioClientProvider)
                .dio
                .post(
                  ApiEndpoints.getSubLocalities,
                  data: {'pincode': pin, 'locality': first},
                  options: Options(contentType: Headers.jsonContentType),
                );
            final subRoot = subRes.data;
            if (subRoot is Map && subRoot['status_code'] == 200) {
              final subResult = subRoot['result'];
              final subs = subResult is Map ? subResult['sublocality'] : null;
              if (subs is List && subs.isNotEmpty) {
                _sublocality.text = subs.first.toString();
              }
            }
          }
        }
      }

      // data.gov postal → state (same source RN verifyPostalCode uses)
      try {
        final gov = await ref
            .read(dioClientProvider)
            .dio
            .get(
              'https://api.data.gov.in/resource/0a076478-3fd3-4e2c-b2d2-581876f56d77',
              queryParameters: {
                'format': 'json',
                'api-key':
                    '579b464db66ec23bdd000001be9925f848ef448249d6231c74b87637',
                'filters[pincode]': pin,
              },
              options: Options(
                extra: {'clearHeader': true},
                contentType: Headers.jsonContentType,
              ),
            );
        final govRoot = gov.data;
        if (govRoot is Map && govRoot['status']?.toString() == 'ok') {
          final records = govRoot['records'];
          if (records is Map && records.isNotEmpty) {
            final first = records.values.first;
            if (first is Map) {
              final stateName = first['statename']?.toString() ?? '';
              final region = first['regionname']?.toString() ?? '';
              if (stateName.isNotEmpty) _state.text = stateName;
              if (_city.text.trim().isEmpty && region.isNotEmpty) {
                _city.text = region;
              }
            }
          } else if (records is List &&
              records.isNotEmpty &&
              records.first is Map) {
            final first = Map<String, dynamic>.from(records.first as Map);
            final stateName = first['statename']?.toString() ?? '';
            final region = first['regionname']?.toString() ?? '';
            if (stateName.isNotEmpty) _state.text = stateName;
            if (_city.text.trim().isEmpty && region.isNotEmpty) {
              _city.text = region;
            }
          }
        }
      } catch (_) {
        // Optional enrichment — city/locality from Django is enough to submit.
      }
    } catch (_) {
      // User can still fill city/state manually.
    } finally {
      if (mounted) setState(() => _lookingUpPin = false);
    }
  }

  Future<void> _submit() async {
    final address = _address.text.trim();
    final postal = _postal.text.trim();
    final city = _city.text.trim();
    final state = _state.text.trim();
    final locality = _locality.text.trim();
    final sublocality = _sublocality.text.trim();

    if (address.isEmpty || postal.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter address and 6-digit pincode')),
      );
      return;
    }
    if (city.isEmpty || state.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter city and state')));
      return;
    }

    ref.read(globalLoadingProvider.notifier).state = true;
    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing customer id — please re-login'),
          ),
        );
        return;
      }

      // RN StoreAddressInfo payload (postal, not pincode).
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.storeAddressInfo,
            data: {
              'city': city,
              'state': state,
              'address': address,
              'localities': locality.isEmpty ? city : locality,
              'sublocalitie': sublocality.isEmpty ? locality : sublocality,
              'customer_id': customerId,
              'postal': postal,
            },
            options: Options(contentType: Headers.jsonContentType),
          );

      final data = response.data;
      final status = data is Map ? data['status'] : null;
      final msg = data is Map ? data['msg']?.toString() : null;
      // 200 = saved; 403 + "already exist" = ok to continue funnel.
      final already =
          msg != null && msg.toLowerCase().contains('already exist');
      if (status != 200 && status != '200' && !already) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg ?? 'Could not save address')),
        );
        return;
      }

      await ref.read(screenStatusServiceProvider).completeAddress();
      // RN ResidenceAddress focus marks bankdetails_verified.
      await ref.read(screenStatusServiceProvider).completeBankVerified();
      if (mounted) context.go(AppRoutes.waiting);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save address')));
      }
    } finally {
      ref.read(globalLoadingProvider.notifier).state = false;
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboard,
    int? maxLength,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboard,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: AppTypography.body(size: 16),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Residence address',
      bottom: ZapSubmitButton(
        title: 'Continue',
        disabled: _lookingUpPin,
        onPressed: _submit,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(controller: _address, hint: 'Full address', maxLines: 3),
          const SizedBox(height: 12),
          _field(
            controller: _postal,
            hint: 'Pincode',
            keyboard: TextInputType.number,
            maxLength: 6,
            onChanged: _onPostalChanged,
            suffix: _lookingUpPin
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _field(controller: _city, hint: 'City'),
          const SizedBox(height: 12),
          _field(controller: _state, hint: 'State'),
          const SizedBox(height: 12),
          _field(controller: _locality, hint: 'Locality'),
          const SizedBox(height: 12),
          _field(controller: _sublocality, hint: 'Sublocality'),
        ],
      ),
    );
  }
}

class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key, this.isTopUp = false});

  /// Re-apply after a repaid loan: an approved decision leads to the offer
  /// screen, not back to Home where the customer started.
  final bool isTopUp;

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  String? _error;
  bool _running = false;
  bool _repeatLoan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Map<String, dynamic>? _offerRow(dynamic root) {
    if (root is List && root.isNotEmpty && root.first is Map) {
      return Map<String, dynamic>.from(root.first as Map);
    }
    if (root is Map) {
      // CD error body: {error, msg, status: 403} — not an offer row.
      final status = root['status'];
      if (status == 403 || status == '403' || root.containsKey('error')) {
        return Map<String, dynamic>.from(root);
      }
      final data = root['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return Map<String, dynamic>.from(data.first as Map);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return Map<String, dynamic>.from(root);
    }
    return null;
  }

  bool _navigateForStatus(String? status) {
    final s = status?.toUpperCase();
    if (s == 'APP') {
      ref.read(homeRefreshTickProvider.notifier).state++;
      context.go(_repeatLoan ? AppRoutes.offer : AppRoutes.home);
      return true;
    }
    if (s == 'REJ') {
      context.go(AppRoutes.rejected);
      return true;
    }
    if (s == 'REF' || s == 'WIP') {
      context.go(AppRoutes.referred, extra: {'status': s});
      return true;
    }
    return false;
  }

  Future<String?> _fetchExistingOfferStatus(String customerId) async {
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .post(
            ApiEndpoints.getCreditDecisionInformation,
            data: {'customer_id': customerId},
            options: Options(contentType: Headers.jsonContentType),
          );
      final row = _offerRow(response.data);
      final status = row?['status']?.toString();
      if (status == '403' || status == null) return null;
      return status;
    } catch (_) {
      return null;
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final storage = ref.read(sessionStorageProvider);
      final customerId = (await storage.read(
        StorageKeys.customerId,
      ))?.replaceAll('"', '');
      if (customerId == null || customerId.isEmpty) {
        setState(() => _error = 'Missing customer id — please re-login');
        return;
      }

      _repeatLoan = widget.isTopUp;
      if (!_repeatLoan) {
        try {
          final bundle = await ref
              .read(homeRepositoryProvider)
              .fetchHomeBundle();
          _repeatLoan = bundle.home.topUpEligible && bundle.home.loanCompleted;
        } catch (_) {
          // Continue with the explicit route flag when Home is unavailable.
        }
      }

      // CD can sleep ~30s waiting for Finbit name-match; allow retries.
      const attempts = 3;
      String? lastDetail;

      for (var i = 0; i < attempts; i++) {
        try {
          final response = await ref
              .read(dioClientProvider)
              .dio
              .post(
                ApiEndpoints.creditDecision,
                data: {'cust_id': customerId},
                options: Options(
                  contentType: Headers.jsonContentType,
                  sendTimeout: const Duration(minutes: 2),
                  receiveTimeout: const Duration(minutes: 2),
                ),
              );
          if (!mounted) return;

          final row = _offerRow(response.data);
          final statusRaw = row?['status'];
          final status = statusRaw?.toString().toUpperCase();

          // Backend exception path returns JSON status 403 (often HTTP 200).
          if (status == '403' || row?['error'] != null) {
            final msg = row?['msg']?.toString();
            lastDetail = msg ?? 'Credit decision failed on server';
            // Offer may already exist from a prior run — check before giving up.
            final existing = await _fetchExistingOfferStatus(customerId);
            if (!mounted) return;
            if (existing != null && _navigateForStatus(existing)) return;
            if (i < attempts - 1) {
              await Future<void>.delayed(const Duration(seconds: 8));
              continue;
            }
            setState(() => _error = lastDetail);
            return;
          }

          if (_navigateForStatus(status)) return;

          // Unknown / empty — Finbit may still be processing.
          lastDetail = status == null || status.isEmpty
              ? 'Decision not ready yet'
              : 'Decision pending ($status)';
          final existing = await _fetchExistingOfferStatus(customerId);
          if (!mounted) return;
          if (existing != null && _navigateForStatus(existing)) return;

          if (i < attempts - 1) {
            await Future<void>.delayed(const Duration(seconds: 8));
            continue;
          }
          setState(
            () => _error =
                '$lastDetail. Finbit/bureau data may still be processing — retry shortly.',
          );
        } on DioException catch (e) {
          lastDetail = e.message ?? 'Network error';
          final existing = await _fetchExistingOfferStatus(customerId);
          if (!mounted) return;
          if (existing != null && _navigateForStatus(existing)) return;
          if (i < attempts - 1) {
            await Future<void>.delayed(const Duration(seconds: 8));
            continue;
          }
          setState(
            () => _error =
                'Could not run credit decision (${e.response?.statusCode ?? e.type}). Try again.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not run credit decision. Try again.');
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Hang tight',
      subtitle: _error == null
          ? 'We are running your credit decision…'
          : 'Credit decision needs another try',
      showBack: false,
      bottom: _error == null
          ? null
          : ZapSubmitButton(
              title: 'Retry',
              disabled: _running,
              onPressed: _run,
            ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error == null
              ? const CircularProgressIndicator(color: AppColors.accentMint)
              : Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.muted),
                ),
        ),
      ),
    );
  }
}

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FunnelScaffold(
      title: 'Application update',
      showBack: false,
      bottom: ZapSubmitButton(
        title: 'Back to home',
        onPressed: () => context.go(AppRoutes.home),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'We are unable to offer a loan at this time. You can re-apply later.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15),
          ),
        ),
      ),
    );
  }
}
