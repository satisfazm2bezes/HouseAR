# 🏡 HouseAR - Augmented Reality Architecture Visualization# 🏡 HouseAR - Augmented Reality Architecture Visualization# 🏡 AR Casa - Visualização de Arquitetura em Realidade Aumentada



A Flutter-based mobile application for visualizing 3D house models in Augmented Reality on real-world terrain using ARCore (Android) and ARKit (iOS).



![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?logo=flutter)A Flutter-based mobile application for visualizing 3D house models in Augmented Reality on real-world terrain using ARCore (Android) and ARKit (iOS).Este projeto permite visualizar um **modelo 3D de uma casa** em **Realidade Aumentada (AR)** diretamente no terreno real, usando o telemóvel.  

![AR](https://img.shields.io/badge/AR-ARCore%20%2B%20ARKit-4285F4)

![License](https://img.shields.io/badge/license-MIT-green)Desenvolvido em **Flutter**, utilizando **ARCore (Android)** e **ARKit (iOS)** através do plugin [`ar_flutter_plugin`](https://pub.dev/packages/ar_flutter_plugin).



## 🚀 Features![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?logo=flutter)



- 📦 Load and render 3D models (`.gltf` / `.glb` format)![AR](https://img.shields.io/badge/AR-ARCore%20%2B%20ARKit-4285F4)---

- 📍 Place models on real-world surfaces with AR plane detection

- 🔄 Interactive model placement with tap-to-place functionality![License](https://img.shields.io/badge/license-MIT-green)

- 🎨 Modern dark theme UI

- 📱 Cross-platform support (Android + iOS)## 🚀 Funcionalidades

- ♻️ Reset and reposition models

- 🎬 Support for animated 3D models## 🚀 Features



## 🧰 Requirements- 📦 Carrega e renderiza modelos 3D (`.glb` / `.gltf`)



### Software- 📦 Load and render 3D models (`.glb` / `.gltf` format)- 📍 Coloca o modelo no chão real com deteção de superfície AR

- Flutter 3.19 or higher

- Dart SDK 3.8.1 or higher- 📍 Place models on real-world surfaces with AR plane detection- 🔄 Ajusta posição, rotação e escala da casa



### Hardware- 🔄 Interactive model placement with tap-to-place functionality- 📱 Suporte multiplataforma (Android + iOS)

- **Android**: Device with ARCore support (Android 7.0+)

- **iOS**: Device with ARKit support (iOS 11+, iPhone 6S or newer)- 🎨 Modern dark theme UI- 🧭 Base para integração futura com GPS e bússola (alinhamento com o terreno real)



> ⚠️ **Note**: AR features require physical devices - emulators are not supported.- 📱 Cross-platform support (Android + iOS)



## 📂 Project Structure- ♻️ Reset and reposition models---



```

HouseAR/

├── lib/## 🧰 Requirements## 🧰 Requisitos

│   ├── main.dart                    # App entry point

│   └── screens/

│       └── ar_house_screen.dart     # Main AR view

├── assets/### Software- Flutter 3.19+  

│   └── models/

│       └── house.gltf               # 3D house model (dummy included)- Flutter 3.19 or higher- Dispositivo com suporte para:

├── android/                         # Android configuration

├── ios/                             # iOS configuration- Dart SDK 3.8.1 or higher  - **ARCore** (Android)

└── pubspec.yaml                     # Dependencies

```  - **ARKit** (iOS)



## ⚙️ Setup & Installation### Hardware- Modelo 3D da casa em formato `.glb` (exportado de Blender, SketchUp, Revit, etc.)



### 1. Clone the Repository- **Android**: Device with ARCore support (Android 7.0+)

```bash

git clone https://github.com/yourusername/HouseAR.git- **iOS**: Device with ARKit support (iOS 11+, iPhone 6S or newer)---

cd HouseAR

```



### 2. Install Dependencies> ⚠️ **Note**: AR features require physical devices - emulators are not supported.## 📂 Estrutura de ficheiros

```bash

flutter pub get

```

## 📂 Project Structurelib/

### 3. Test with Included Model

├── main.dart

The project includes a simple red cube model (`house.gltf`) for testing. To use your own model:

```└── screens/

**Model Requirements:**

- Format: glTF 2.0 (.gltf or .glb)HouseAR/└── ar_house_screen.dart

- Coordinate System: +Y Up

- Include materials and textures├── lib/assets/

- Recommended polygon count: < 100k for mobile performance

│   ├── main.dart                    # App entry point└── models/

#### Exporting from Blender

1. Select your house model│   └── screens/└── casa.glb

2. File > Export > glTF 2.0 (.glb/.gltf)

3. Enable these options:│       └── ar_house_screen.dart     # Main AR viewpubspec.yaml

   - ✅ Include → Selected Objects

   - ✅ Transform → +Y Up├── assets/README.md

   - ✅ Include Materials/Textures

4. Save as `house.gltf` or `house.glb` in `assets/models/`│   └── models/



### 4. Run the App│       └── house.glb                # 3D house model (add your own)



**Android:**├── android/                         # Android configuration---

```bash

flutter run├── ios/                             # iOS configuration

```

└── pubspec.yaml                     # Dependencies## ⚙️ Configuração do projeto

**iOS:**

```bash```

cd ios

pod install### 1. Criar projeto Flutter

cd ..

flutter run## ⚙️ Setup & Installation```bash

```

flutter create ar_casa

## 🎮 How to Use

### 1. Clone the Repositorycd ar_casa

1. **Launch** the app on your AR-capable device

2. **Point** your camera at a flat horizontal surface (floor, table, ground)```bash

3. **Wait** for the AR system to detect the surface (you'll see plane indicators)

4. **Tap** anywhere on the detected surface to place the 3D modelgit clone https://github.com/yourusername/HouseAR.git2. Adicionar dependências

5. **Reset** using the refresh button in the app bar to reposition

cd HouseAR

## 🛠️ Configuration

```No pubspec.yaml:

### Android Permissions

Already configured in `android/app/src/main/AndroidManifest.xml`:

- Camera access

- ARCore requirement### 2. Install Dependenciesdependencies:

- Internet (for loading remote resources)

```bash  flutter:

### iOS Permissions

Already configured in `ios/Runner/Info.plist`:flutter pub get    sdk: flutter

- Camera usage description

- ARKit requirement```  ar_flutter_plugin: ^1.2.0



## 🧱 Key Dependencies



```yaml### 3. Add Your 3D Model3. Adicionar o modelo 3D

ar_flutter_plugin_2: ^0.0.3  # Modern AR plugin using Sceneview

vector_math: ^2.1.4          # 3D transformations

```

Place your `.glb` model file in `assets/models/house.glb`Coloca o teu modelo .glb em:

> **⚡ Important**: This project uses `ar_flutter_plugin_2`, the modern successor to the discontinued `ar_flutter_plugin`. The new version migrates from the archived Sceneform to Sceneview, supporting the latest ARCore versions with Google Filament as the 3D engine. This enables animated model support and many improvements.



## 📱 Supported Platforms

**Model Requirements:**assets/models/casa.glb

| Platform | Minimum Version | AR Framework |

|----------|----------------|--------------|- Format: glTF 2.0 (.glb recommended)

| Android  | 7.0 (API 24)   | ARCore       |

| iOS      | 11.0           | ARKit        |- Coordinate System: +Y UpE adiciona em pubspec.yaml:



## 🔧 Development- Include materials and textures



### Build Commands- Recommended polygon count: < 100k for mobile performanceflutter:



```bash  assets:

# Debug build

flutter run#### Exporting from Blender    - assets/models/casa.glb



# Release build (Android)1. Select your house model

flutter build apk --release

2. File > Export > glTF 2.0 (.glb)📱 Código de exemplo

# Release build (iOS)

flutter build ios --release3. Enable these options:

```

   - ✅ Include → Selected ObjectsCria o ficheiro lib/screens/ar_house_screen.dart:

### Testing AR Features

   - ✅ Transform → +Y Up

AR functionality can only be tested on physical devices:

   - ✅ Include Materials/Texturesimport 'package:flutter/material.dart';

```bash

# List connected devices4. Save as `house.glb`import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';

flutter devices

import 'package:vector_math/vector_math_64.dart';

# Run on specific device

flutter run -d <device_id>### 4. Run the App

```

class ARHouseScreen extends StatefulWidget {

## 💡 Future Enhancements

**Android:**  @override

- [ ] GPS/compass alignment for real-world orientation

- [ ] Sun simulation for realistic shadows```bash  _ARHouseScreenState createState() => _ARHouseScreenState();

- [ ] Material swapping (walls, roofs, windows)

- [ ] Multiple model selectionflutter run}

- [ ] Save/load AR anchor positions

- [ ] Miniature mode for tabletop viewing```

- [ ] Screenshot/video recording

- [ ] Model animation support (enabled by new plugin)class _ARHouseScreenState extends State<ARHouseScreen> {

- [ ] Cloud anchors for shared AR experiences

**iOS:**  ARSessionManager? arSessionManager;

## 🐛 Troubleshooting

```bash  ARObjectManager? arObjectManager;

### "AR not supported" error

- Verify your device is ARCore/ARKit compatiblecd ios  ARNode? houseNode;

- Check that camera permissions are granted

- Ensure you're running on a physical device, not an emulatorpod install



### Model not appearingcd ..  @override

- Verify model file exists in `assets/models/`

- Check the file is properly declared in `pubspec.yaml`flutter run  Widget build(BuildContext context) {

- Try the included dummy model first (`house.gltf`)

- Run `flutter clean && flutter pub get````    return Scaffold(



### Build errors      appBar: AppBar(title: const Text('Casa em Realidade Aumentada')),

```bash

# Clean and rebuild## 🎮 How to Use      body: ARView(

flutter clean

flutter pub get        onARViewCreated: onARViewCreated,

cd ios && pod install && cd ..

flutter run1. **Launch** the app on your AR-capable device      ),

```

2. **Point** your camera at a flat horizontal surface (floor, table, ground)    );

### "Plugin not found" error

- Make sure you're using `ar_flutter_plugin_2` (not the old `ar_flutter_plugin`)3. **Wait** for the AR system to detect the surface (you'll see visual indicators)  }

- Run `flutter pub get` to ensure dependencies are installed

- Restart your IDE4. **Tap** anywhere on the detected surface to place the house model



## 📚 Resources5. **Reset** using the refresh button in the app bar to reposition  Future<void> onARViewCreated(



- [ar_flutter_plugin_2 Documentation](https://pub.dev/packages/ar_flutter_plugin_2)    ARSessionManager sessionManager,

- [ARCore Documentation](https://developers.google.com/ar)

- [ARKit Documentation](https://developer.apple.com/augmented-reality/)## 🛠️ Configuration    ARObjectManager objectManager,

- [glTF Format Specification](https://www.khronos.org/gltf/)

    ARAnchorManager anchorManager,

## 📄 License

### Android Permissions  ) async {

This project is available for personal and educational use. For commercial use, please verify licenses for 3D models and the AR plugin.

Already configured in `android/app/src/main/AndroidManifest.xml`:    arSessionManager = sessionManager;

## 🤝 Contributing

- Camera access    arObjectManager = objectManager;

Contributions are welcome! Please feel free to submit a Pull Request.

- ARCore requirement

## 📧 Contact

- Internet (for loading resources)    // Ativar deteção de planos

For questions or support, please open an issue on GitHub.

    await arSessionManager!.setupSession();

---

### iOS Permissions

**Built with ❤️ using Flutter and modern AR technology**

Already configured in `ios/Runner/Info.plist`:    // Carregar o modelo 3D da casa

- Camera usage description    houseNode = ARNode(

- ARKit requirement      type: NodeType.localGLTF2,

      uri: "assets/models/casa.glb",

## 🧱 Key Dependencies      scale: Vector3(1.0, 1.0, 1.0),

      position: Vector3(0.0, 0.0, -2.0),

```yaml    );

ar_flutter_plugin: ^0.7.3   # AR functionality wrapper for ARCore/ARKit

vector_math: ^2.1.4         # 3D transformations    await arObjectManager!.addNode(houseNode!);

```  }



## 📱 Supported Platforms  @override

  void dispose() {

| Platform | Minimum Version | AR Framework |    arSessionManager?.dispose();

|----------|----------------|--------------|    super.dispose();

| Android  | 7.0 (API 24)   | ARCore       |  }

| iOS      | 11.0           | ARKit        |}



## 🔧 DevelopmentNo lib/main.dart:



### Build Commandsimport 'package:flutter/material.dart';

import 'screens/ar_house_screen.dart';

```bash

# Debug buildvoid main() {

flutter run  runApp(const ARCasaApp());

}

# Release build (Android)

flutter build apk --releaseclass ARCasaApp extends StatelessWidget {

  const ARCasaApp({super.key});

# Release build (iOS)

flutter build ios --release  @override

```  Widget build(BuildContext context) {

    return MaterialApp(

### Testing AR Features      title: 'AR Casa',

      theme: ThemeData.dark(),

AR functionality can only be tested on physical devices:      home: ARHouseScreen(),

    );

```bash  }

# List connected devices}

flutter devices

🧱 Exportar o modelo 3D para .glb

# Run on specific device

flutter run -d <device_id>Se usares Blender, segue estes passos:

```

    Importa o teu modelo (por exemplo, .fbx, .obj, .skp).

## 💡 Future Enhancements

    Ajusta a escala e origem.

- [ ] GPS/compass alignment for real-world orientation

- [ ] Sun simulation for realistic shadows    Vai a File > Export > glTF 2.0 (.glb).

- [ ] Material swapping (walls, roofs, windows)

- [ ] Multiple model selection    Marca as opções:

- [ ] Save/load AR anchor positions

- [ ] Miniature mode for tabletop viewing        ✅ Include → Selected Objects

- [ ] Screenshot/video recording

        ✅ Transform → +Y Up

## 🐛 Troubleshooting

        ✅ Include Materials / Textures

### "AR not supported" error

- Verify your device is ARCore/ARKit compatible    Guarda como casa.glb.

- Check that camera permissions are granted

- Ensure you're running on a physical device, not an emulator📸 Como usar no terreno



### Model not appearing    Abre a app no teu telemóvel.

- Verify `house.glb` exists in `assets/models/`

- Check the file is properly declared in `pubspec.yaml`    Aponta a câmara para o chão (espera que apareçam os pontos AR).

- Run `flutter clean && flutter pub get`

    Toca no ecrã para posicionar a casa.

### Build errors

```bash    Move, roda e redimensiona conforme necessário.

# Clean and rebuild

flutter clean    Observa a casa sobreposta ao terreno real 🏡✨

flutter pub get

cd ios && pod install && cd ..💡 Ideias futuras

flutter run

```    🌍 Alinhar o modelo com coordenadas GPS reais



## 📄 License    ☀️ Simular iluminação e sombras do sol real



This project is available for personal and educational use. For commercial use, please verify licenses for 3D models and the AR plugin.    🪟 Modo “Miniatura” para visualizar sobre uma mesa



## 🤝 Contributing    🧱 Trocar materiais (pinturas, telhados, janelas)



Contributions are welcome! Please feel free to submit a Pull Request.    💾 Guardar posição e revisitar o ponto AR



## 📧 Contact📜 Licença



For questions or support, please open an issue on GitHub.Este projeto é livre para uso pessoal e académico.

Para uso comercial, verifica as licenças dos modelos 3D e do plugin.

---✨ Autor



**Built with ❤️ using Flutter and AR technology**Desenvolvido com ❤️ em Flutter.



---

Queres que eu acrescente também uma **secção opcional de integração com GPS/bússola** (para alinhar autom