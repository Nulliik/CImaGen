import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cimagen/utils/ImageManager.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'package:win32/win32.dart';

import 'main.dart';

class ConfigManager with ChangeNotifier {
  int _count = 0;

  //Getter
  int get count => _count;

  String _tempDir = './temp';
  String get tempDir => _tempDir;

  bool _isNull = false;
  bool get isNull => _isNull;

  Future<void> init() async {
    updateCacheLocation();
    if(Platform.isWindows){
      _isNull = (getUserName() == 'aandr' && getComputerName().toLowerCase() == 'workhorse') || (getUserName() == 'TurboBox' && getComputerName() == 'TurboBox');
    }
  }

  Future<String> updateCacheLocation() async {
    String? customCacheDir = prefs!.getString('custom_cache_dir');
    Directory tDir;
    if(customCacheDir != null){
      tDir = Directory(customCacheDir);
    } else {
      Directory appTempDir = await getTemporaryDirectory();
      tDir = Directory(p.join(appTempDir.path, 'cImagen'));
    }

    if(!tDir.existsSync()){
      tDir.createSync(recursive: true);
    }
    _tempDir = tDir.path;
    return _tempDir;
  }

  void increment() {
    _count++;
  }
}

String getUserName() {
  const usernameLength = 256;
  final pcbBuffer = calloc<DWORD>()..value = usernameLength + 1;
  final lpBuffer = wsalloc(usernameLength + 1);

  try {
    final result = GetUserName(lpBuffer, pcbBuffer);
    if (result != 0) {
      return lpBuffer.toDartString();
    } else {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
  } finally {
    free(pcbBuffer);
    free(lpBuffer);
  }
}

String getComputerName() {
  final nameLength = calloc<DWORD>();
  String name;

  GetComputerNameEx(COMPUTER_NAME_FORMAT.ComputerNameDnsFullyQualified, nullptr, nameLength);

  final namePtr = wsalloc(nameLength.value);

  try {
    final result = GetComputerNameEx(
        COMPUTER_NAME_FORMAT.ComputerNameDnsFullyQualified,
        namePtr,
        nameLength);

    if (result != 0) {
      name = namePtr.toDartString();
    } else {
      throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
    }
  } finally {
    free(namePtr);
    free(nameLength);
  }
  return name;
}

Color getColor(int index){
  List<Color> c = [
    const Color(0xffea4b49),
    const Color(0xfff88749),
    const Color(0xfff8be46),
    const Color(0xff89c54d),
    const Color(0xff48bff9),
    const Color(0xff5b93fd),
    const Color(0xff9c6efb)
  ];
  return c[index % c.length];
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();
String getRandomString(int length) => String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

int getRandomInt(int min, int max) {
  return min + _rnd.nextInt(max - min);
}

// FS
Future<Uint8List> readAsBytesSync(String path) async {
  return File(path).readAsBytesSync();
}

// TODO Rewrite this stupid shit
GenerationParams? parseSDParameters(String rawData){
  try{
    RegExp ex = RegExp(r'\s*(\w[\w \-/]+):\s*("(?:\\.|[^\\"])+"|[^,]*)(?:,|$)');

    Map<String, Object> gp = <String, Object>{};

    // Generation params
    List<String> lines = rawData.trim().split("\n");

    bool doneWithPrompt = false;
    bool doneWithNegative = false;
    bool doneWithGenerationParams = false;
    bool doneWithPositiveTemplate = false;
    bool doneWithNegativeTemplate = false;

    String positivePromt = '';
    String negativePromt = '';

    String generationParams = '';

    String positiveTemplate = '';
    String negativeTemplate = '';

    for(String line in lines){
      line = line.trim();
      if(line.startsWith('Negative prompt:')){
        doneWithPrompt = true;
        line = line.substring(16+1, line.length).trim();
      }
      if(line.startsWith('Steps:')){
        doneWithPrompt = true;
        doneWithNegative = true;
        line = line.trim();
      }
      if(doneWithPrompt){
        if(line.startsWith('Template:')){
          doneWithNegative = true;
          doneWithGenerationParams = true;
          line = line.substring(9+1, line.length).trim();
        }
        if(!doneWithNegative){
          negativePromt += (negativePromt == "" ? '' : "\n") + line;
        } else {
          if(line.startsWith('Template:')){
            doneWithGenerationParams = true;
            line = line.substring(9+1, line.length).trim();
          }
          if(!doneWithGenerationParams){
            generationParams += (generationParams == "" ? '' : "\n") + line;
          } else {
            if(line.startsWith('Negative Template:')){
              doneWithPositiveTemplate = true;
              line = line.substring(18+1, line.length).trim();
            }
            if(!doneWithPositiveTemplate){
              positiveTemplate += (positiveTemplate == "" ? '' : "\n") + line;
            } else {
              negativeTemplate += (negativeTemplate == "" ? '' : "\n") + line;
            }
          }
        }
      } else {
        positivePromt += (positivePromt == "" ? '' : "\n") + line;
      }
    }

    Iterable<RegExpMatch> matches = ex.allMatches(generationParams);

    for (final m in matches) {
      try{
        gp.putIfAbsent(m[1]!.toLowerCase().replaceAll(RegExp(r' '), '_'), () => m[2] ?? 'null');
      } on RangeError catch(e){
        print(e.message);
        print(e.stackTrace);
      }
    }

    bool isRefiner = gp['refiner'] != null;
    bool isUNET = gp['unet'] != null;

    Object? model = gp[isRefiner ? 'refiner' : isUNET ? 'unet' : 'model'];

    GenerationParams gpF = GenerationParams(
        positive: positivePromt,
        negative: negativePromt,
        steps: int.parse(gp['steps'] as String),
        sampler: gp['sampler'] as String,
        cfgScale: double.parse(gp['cfg_scale'] as String),
        seed: int.parse(gp['seed'] as String),
        size: sizeFromString(gp['size'] as String),
        checkpointType: isRefiner ? CheckpointType.refiner : isUNET ? CheckpointType.unet : gp['model'] != null ? CheckpointType.model : CheckpointType.unknown,
        checkpoint: model != null ? model as String : null,
        checkpointHash: gp['model_hash'] != null ? gp['model_hash'] as String : null,
        denoisingStrength: gp['denoising_strength'] != null ? double.parse(gp['denoising_strength'] as String) : null,
        rng: gp['rng'] != null ? gp['rng'] as String : null,
        hiresSampler: gp['hires_sampler'] != null ? gp['hires_sampler'] as String : null,
        hiresUpscaler: gp['hires_upscaler'] != null ? gp['hires_upscaler'] as String : null,
        hiresUpscale: gp['hires_upscale'] != null ? double.parse(gp['hires_upscale'] as String) : null,
        version: gp['version']  != null ? gp['version'] as String : null,
        all: gp,
        rawData: rawData
    );
    return gpF;
  } catch(e){
    return null;
  }
}

// TODO: Потом покурю
void parseComfUIParameters(String rawData){
  var data = jsonDecode(rawData);
  if(data['nodes'] != null){
    // Vanilla ComfUI
  }
}

// Steps: 35,
// Sampler: Euler a,
// CFG scale: 7,
// Seed: 3658053067,
// Size: 512x512,
// Model hash: 1ac4dcb22c,
// Model: EasyFluffV10.1,
// Denoising strength: 0.42,
// RNG: NV,
// RP Active: True,
// RP Divide mode: Mask,
// RP Matrix submode: Rows,
// RP Mask submode: Mask,
// RP Prompt submode: Prompt,
// RP Calc Mode: Attention,
// RP Ratios: "1,3;2;1,1",
// RP Base Ratios: 0.2,
// RP Use Base: False,
// RP Use Common: True,
// RP Use Ncommon: False,
// RP Options: ["[", "\"", "[", "\""],
// RP LoRA Neg Te Ratios: 0,
// RP LoRA Neg U Ratios: 0,
// RP threshold: 0.4,
// RP LoRA Stop Step: 0,
// RP LoRA Hires Stop Step: 0,
// RP Flip: False,
// Hires sampler: DPM++ 3M SDE,
// Hires upscale: 1.5,
// Hires upscaler: Latent,
// TI hashes: "deformityv6: 8455ec9b3d31, easynegative: c74b4e810b03",
// Version: 1.7.0
class GenerationParams {
  final String positive;
  final String negative;
  final int steps;
  final String sampler;
  final double cfgScale;
  final int seed;
  final ImageSize size;
  final CheckpointType checkpointType;
  final String? checkpoint;
  final String? checkpointHash;
  final double? denoisingStrength;
  final String? rng;
  final String? hiresSampler;
  final String? hiresUpscaler;
  final double? hiresUpscale;
  final Map<String, String>? tiHashes;
  final String? version;
  final String? rawData;
  final Map<String, dynamic>? all;

  const GenerationParams({
    required this.positive,
    required this.negative,
    required this.steps,
    required this.sampler,
    required this.cfgScale,
    required this.seed,
    required this.size,
    required this.checkpointType,
    required this.checkpoint,
    required this.checkpointHash,
    this.denoisingStrength,
    this.rng,
    this.hiresSampler,
    this.hiresUpscaler,
    this.hiresUpscale,
    this.tiHashes,
    required this.version,
    this.rawData,
    this.all
  });

  Map<String, dynamic> toMap({bool forDB = false, ImageKey? key, Map<String, dynamic>? amply}) {
    Map<String, dynamic> f = {
      'positive': positive,
      'negative': negative,
      'steps': steps,
      'sampler': sampler,
      'cfgScale': cfgScale,

      'seed': seed,
      'checkpointType': checkpointType.index,
      'checkpoint': checkpoint,
      'checkpointHash': checkpointHash,
      'version': version,
    };

    if (!forDB){
      f['size'] = size.toString();
    } else {
      //forDB
      f['sizeW'] = size.width;
      f['sizeH'] = size.height;
      if(rawData != null) f['rawData'] = rawData;
      if(key != null){
        f['keyup'] = key.keyup;
        f['type'] = key.type.index;
        f['parent'] = key.parent;
        f['fileName'] = key.fileName;
        f['isLocal'] = key.host == null ? 1 : 0;
        f['host'] = key.host;
      } else {
        throw Exception('Пошёл нахуй');
      }
    }

    if (denoisingStrength != null) f['denoisingStrength'] = denoisingStrength;
    if (rng != null) f['rng'] = rng;
    if (hiresSampler != null) f['hiresSampler'] = hiresSampler;
    if (hiresUpscaler != null) f['hiresUpscaler'] = hiresUpscaler;
    if (hiresUpscale != null) f['hiresUpscale'] = hiresUpscale;
    if (tiHashes != null) f['tiHashes'] = tiHashes;

    if(amply != null){
      for(String key in amply.keys) {
        f[key] = amply[key];
      }
    }

    return f;
  }

  String toJsonString(){
    return jsonEncode(toMap());
  }
}

ImageSize sizeFromString(String s){
  final List<String> ar = s.split('x');
  return ImageSize(width: int.parse(ar[0]), height: int.parse(ar[1]));
}

String genPathHash(String path){
  List<int> bytes = utf8.encode(path);
  String hash = sha256.convert(bytes).toString();
  return hash;
}

bool isImage(dynamic file){
  final String e = p.extension(file.path);
  return ['png', 'jpg', 'webp', 'jpeg'].contains(e.replaceFirst('.', ''));
}

String readableFileSize(int size, {bool base1024 = true}) {
  final base = base1024 ? 1024 : 1000;
  if (size <= 0) return "0";
  final units = ["B", "kB", "MB", "GB", "TB"];
  int digitGroups = (log(size) / log(base)).round();
  return "${NumberFormat("#,##0.#").format(size / pow(base, digitGroups))}${units[digitGroups]}";
}

bool isRaw(dynamic image) => image.runtimeType != ImageMeta;


String aspectRatioFromSize(ImageSize size) => aspectRatio(size.width, size.height);
String aspectRatio(int width, int height){
  int r = _gcd(width, height);
  return '${(width/r).round()}:${(height/r).round()}';
}

int _gcd(int a, int b) {
  return b == 0 ? a : _gcd(b, a%b);
}

dynamic readMetadataFromSafetensors(String path) async {
  RandomAccessFile file = await File(path).open(mode: FileMode.read);
  var main = await file.read(8);
  int metadataLen = bytesToInteger(main);
  var jsonStart = await file.read(2);
  if(!(metadataLen > 2 && ['{"', "{'"].contains(utf8.decode(jsonStart)))){
    return null;
  } else {
    var jsonData = jsonStart + await file.read(metadataLen - 2);
    return utf8.decode(jsonData);
  }
}

int bytesToInteger(List<int> bytes) {
  int value = 0;
  for (var i = 0, length = bytes.length; i < length; i++) {
    value += bytes[i] * pow(256, i).toInt();
  }
  return value;
}

Future<void> showInExplorer(String file) async {
  if(Platform.isWindows){
    Process.run('explorer.exe ', [ '/select,', file]);
  } else {
    final Uri launchUri = Uri(
      scheme: 'file',
      path: file,
    );
    if (await canLaunchUrl(launchUri)) {
      launchUrl(launchUri);
    }
  }
}

Future<bool> isJson(String text) async {
  try{
    await json.decode(text);
    return true;
  } catch (e) {
    return false;
  }
}

Color getRandomColor(){
  return Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
}

Color fromHex(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

List<int> _daysInMonth365 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

bool isValidDate(int year, int month, int day) {
  if (year < 1 || year > 9999 || month < 0 || month > 11) return false;

  int daysInMonth = _daysInMonth365[month];
  if (month == 1) {
    bool isLeapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    if (isLeapYear) daysInMonth++;
  }
  return day >= 1 && day <= daysInMonth;
}

bool isValidTime(int hours, int minutes, int seconds) {
  return hours >= 0 && hours < 24
      && minutes >= 0 && minutes < 60
      && seconds >= 0 && seconds < 60;
}

bool isHDR(String profileName){
  return ['ITUR_2100_PQ_FULL'].contains(profileName);
}

bool get isOnDesktopAndWeb {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

Future<String> getDeviceInfo() async {
  String f = '';

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if(Platform.isWindows){
    WindowsDeviceInfo info = await deviceInfo.windowsInfo;
    f += 'Build Lab: ${info.buildLab}\n';
    f += 'Build Lab Ex: ${info.buildLabEx}\n';
    f += 'Build Number: ${info.buildNumber}\n';
    f += 'Computer Name: ${info.computerName}\n';
    f += 'CSD Version: ${info.csdVersion}\n';
    f += 'Device ID: ${info.deviceId}\n';
    f += 'Display Version: ${info.displayVersion}\n';
    f += 'Edition ID: ${info.editionId}\n';
    f += 'Registered Owner: ${info.registeredOwner}\n';
    f += 'Release ID: ${info.releaseId}\n';
    f += 'User Name: ${info.userName}\n';
  }
  return f;
}

// https://e621.net/db_export/
