import 'dart:io';

import 'package:cimagen/pages/sub/DBExtra.dart';
import 'package:cimagen/pages/sub/GitHubCommits.dart';
import 'package:cimagen/pages/sub/RemoteVersionSettings.dart';
import 'package:cimagen/utils/ThemeManager.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:provider/provider.dart';

import 'package:settings_ui/settings_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:path/path.dart' as p;

import '../Utils.dart';
import '../main.dart';
import '../modules/webUI/OnLocal.dart';
import '../utils/SQLite.dart';

class Settings extends StatefulWidget{
  const Settings({ Key? key }): super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings>{
  // Settings
  String _sd_webui_folder = '';
  bool _use_remote_version = false;

  bool _debug = false;
  bool _imageview_use_fullscreen = false;

  String _custom_cache_dir = '-';

  String appDocumentsPath = '';
  String appTempPath = '';
  String? documentsPath = '';
  String appVersion = '-';

  String _deviceInfo = '-';

  Map<String, double> dataMap = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    Directory appTempDir = await getTemporaryDirectory();
    if(Platform.isAndroid){
      documentsPath = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOCUMENTS);
    } else if(Platform.isWindows){
      documentsPath = appDocumentsDir.path;
    }
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String deviceInfo = await getDeviceInfo();

    setState(() {
      _sd_webui_folder = prefs!.getString('sd_webui_folder') ?? 'none';
      _use_remote_version = prefs!.getBool('use_remote_version') ?? false;
      _debug = prefs!.getBool('debug') ?? false;
      _imageview_use_fullscreen = (prefs!.getBool('imageview_use_fullscreen') ?? false);
      appDocumentsPath = appDocumentsDir.absolute.path;
      appTempPath = appTempDir.absolute.path;
      appVersion = packageInfo.version;
      _deviceInfo = deviceInfo;
      _custom_cache_dir = context.read<ConfigManager>().tempDir;
    });

    context.read<SQLite>().getTablesInfo().then((value) => {
      setState(() {
        dataMap = {
          'txt2img (${readableFileSize(value['txt2imgSumSize'] as int)})': (value['txt2imgCount'] as int).toDouble(),
          'img2img (${readableFileSize(value['img2imgSumSize'] as int)})': (value['img2imgCount'] as int).toDouble(),
          'Without meta': (value['totalImages'] as int) - (value['totalImagesWithMetadata'] as int).toDouble()
        };
      })
    });
  }

  @override
  Widget build(BuildContext context) {
    Color f = SystemTheme.accentColor.accent;
    return Center(
        child: SettingsList(
          lightTheme: SettingsThemeData(
            leadingIconsColor: Theme.of(context).colorScheme.primary,
            settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
            titleTextColor: Theme.of(context).primaryColor,
            tileDescriptionTextColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            settingsTileTextColor: Theme.of(context).textTheme.bodyMedium?.color
          ),
          brightness: context.read<ThemeManager>().isDark ? Brightness.dark : Brightness.light,
          shrinkWrap: true,
          platform: DevicePlatform.fuchsia,
          sections: [
            SettingsSection(
              title: const Text('Common'),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  enabled: _use_remote_version == false,
                  leading: const Icon(Icons.web),
                  title: const Text('Stable Diffusion web UI location'),
                  value: Text(_use_remote_version ? 'Turn off the remote version to use the local version' : _sd_webui_folder),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      prefs.setString('sd_webui_folder', selectedDirectory);
                      setState(() {
                        _sd_webui_folder = selectedDirectory;
                      });
                      prefs.getKeys().forEach((element) {
                        print(prefs.get(element));
                      });
                    }
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.cached),
                  title: const Text('Cache Location'),
                  value: Text('The place where the cache will be located (temporary shit that can be deleted after a while)\nNow: $_custom_cache_dir'),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                    if (selectedDirectory != null) {
                      List<FileSystemEntity> fe = await dirContents(Directory(selectedDirectory));
                      if(fe.isNotEmpty){
                        Directory tDir = Directory(p.join(selectedDirectory, 'cImagen'));
                        tDir.create(recursive: true).then((va){
                          setState(() {
                            _custom_cache_dir = va.path;
                          });
                          prefs.setString('custom_cache_dir', va.path);
                          context.read<ConfigManager>().updateCacheLocation();
                        });
                      } else {
                        prefs.setString('custom_cache_dir', selectedDirectory);
                        context.read<ConfigManager>().updateCacheLocation();
                      }
                    }
                  },
                ),
                SettingsTile(
                  leading: Icon(Icons.restart_alt),
                  title: Text('Restore the default cache location'),
                  onPressed: (context) async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    prefs.remove('custom_cache_dir');
                    context.read<ConfigManager>().updateCacheLocation().then((value){
                      setState(() {
                        _custom_cache_dir = value;
                      });
                    });
                  },
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.network_check_rounded),
                  title: Text('Remote version settings'),
                  description: Text('Specify the IP address to access the WebUI or select a network folder'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RemoteVersionSettings()));
                  },
                ),
                SettingsTile.switchTile(
                  onToggle: (v) {
                    setState(() {
                      _debug = v;
                    });
                    prefs!.setBool('debug', v);
                  },
                  leading: Icon(Icons.bug_report),
                  title: Text('Enable debug'), initialValue: _debug,
                ),
              ],
            ),
            SettingsSection(
              title: Text('UI & UX'),
              tiles: <SettingsTile>[
                SettingsTile.switchTile(
                  leading: Icon(Icons.fullscreen),
                  title: const Text('Full-screen mode when viewing images'),
                  description: Text('When viewing images, the upper control frame will be completely removed'),
                  onToggle: (v) {
                    setState(() {
                      _imageview_use_fullscreen = v;
                    });
                    prefs!.setBool('imageview_use_fullscreen', v);
                  }, initialValue: _imageview_use_fullscreen,
                ),
              ],
            ),
            SettingsSection(
              title: const Text('Database'),
              tiles: [
                DBChart(dataMap: dataMap),
                SettingsTile(
                  leading: Icon(Icons.delete),
                  title: Text('Clear image database'),
                  description: Text('Previews, image data. The list of favorites will remain untouched'),
                  onPressed: (context){
                    showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          icon: Icon(Icons.warning_amber_outlined),
                          title: const Text('Are you sure you want to delete the cache?'),
                          content: const Text('The application will take some time to read all the images again'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => context.read<SQLite>().clearMeta().then((value) => Navigator.pop(context, 'Ok')),
                              child: const Text('Okay'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'Cancel'),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                    );
                  },
                ),
                SettingsTile(
                  leading: Icon(Icons.warning),
                  title: Text('Extra'),
                  description: Text('Not recommended for noobs'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DBExtra()));
                  },
                )
              ],
            ),
            SettingsSection(
              title: const Text('Device info'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Platform.isAndroid ? Icons.phone_android : Icons.desktop_windows , color: f),
                  title: const Text('Device'),
                  description: SelectableText(_deviceInfo),
                ),
                SettingsTile(
                  leading: Icon(Icons.folder ),
                  title: const Text('Paths'),
                  description: Text(''
                      'App Documents\n↳ $appDocumentsPath\n'
                      'App Temp\n↳ $appTempPath\n'
                      'Documents\n↳ $documentsPath\n'),
                )
              ],
            ),
            SettingsSection(
              title: const Text('CImaGen'),
              tiles: <SettingsTile>[
                SettingsTile(
                  leading: Icon(Platform.isAndroid ? Icons.phone_android : Icons.desktop_windows ),
                  title: const Text('App'),
                  description: Text(appVersion),
                ),
                SettingsTile(
                  leading: Icon(Icons.system_update_alt),
                  title: Text('Updates'),
                  description: Text('View the list of changes'),
                  onPressed: (context){
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GitHubCommits()));
                  },
                )
              ],
            ),
          ],
        ),
    );
  }
}

class DBChart extends AbstractSettingsTile{
  Map<String, double> dataMap = {};

  DBChart({
    super.key,
    required this.dataMap,
  });

  List<List<Color>> colorList = [
    [],                       // 0
    [const Color(0xffffffff)], // 1
    [
      const Color(0xffe20000),
      const Color(0xff03ce6c)
    ], // 2
    [
      const Color(0xff6407f6),
      const Color(0xff01e5fc),
      const Color(0xff1df400)
    ], // 3
    [
      const Color(0xff197bf7),
      const Color(0xff000146),
      const Color(0xffe00081),
      const Color(0xfff8e71a)
    ], // 4
    [
      const Color(0xff26f8b8),
      const Color(0xffcbc20a),
      const Color(0xfffc8c0e),
      const Color(0xffd63d50),
      const Color(0xff2800ff)
    ], // 5
    [ // TODO
      const Color(0xff26f8b8),
      const Color(0xffcbc20a),
      const Color(0xfffc8c0e),
      const Color(0xffd63d50),
      const Color(0xff2800ff),
      const Color(0xffd63d50),
      const Color(0xff2800ff)
    ], // 6
    [ // TODO
      const Color(0xff26f8b8),
      const Color(0xffcbc20a),
      const Color(0xfffc8c0e),
      const Color(0xffd63d50),
      const Color(0xff2800ff),
      const Color(0xffd63d50),
      const Color(0xff2800ff)
    ], // 7
    [
      const Color(0xffe56a02),
      const Color(0xfffedf00),
      const Color(0xff54fca6),
      const Color(0xff13e4e8),
      const Color(0xff0271fc),
      const Color(0xff5f0073),
      const Color(0xff8c0241),
      const Color(0xffba301f),
    ] // 8
  ];

  @override
  Widget build(BuildContext context) {
    return dataMap.isNotEmpty ? PieChart(
      dataMap: dataMap,
      animationDuration: const Duration(milliseconds: 800),
      chartLegendSpacing: 40,
      chartRadius: 200,
      colorList: colorList[dataMap.keys.length],
      initialAngleInDegree: 0,
      chartType: ChartType.ring,
      ringStrokeWidth: 18,
      centerText: dataMap.values.reduce((a, b) => a + b).round().toString(),
      legendOptions: const LegendOptions(
        showLegendsInRow: true,
        legendPosition: LegendPosition.bottom,
        showLegends: true,
        legendShape: BoxShape.circle,
        legendTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      chartValuesOptions: const ChartValuesOptions(
        showChartValueBackground: true,
        showChartValues: true,
        showChartValuesInPercentage: false,
        showChartValuesOutside: true,
        decimalPlaces: 0,
      ),
    ) : const LinearProgressIndicator();
  }
}