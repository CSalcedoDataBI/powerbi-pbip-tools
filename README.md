# 🛠️ Power BI PBIP Tools

Automation tools for Power BI projects in **PBIP format**. Streamline your workflow with batch operations, SVG manipulation, and more.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Power BI](https://img.shields.io/badge/Power%20BI-PBIP-yellow)](https://powerbi.microsoft.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)

## 🎯 What is PBIP?

PBIP (Power BI Project) is an **open format** that stores Power BI reports and semantic models as **plain text files**. This enables:

- ✅ Version control with Git
- ✅ Offline editing without Power BI Desktop
- ✅ Automation and batch operations
- ✅ Team collaboration

## 🚀 Available Tools

### 📦 SVG Recolor

Automatically change the color of **all SVG icons** in your Power BI report.

**Use case**: You have 142 icons and want to change them from blue to red in 2 seconds.

```powershell
# Detect colors in your project
.\svg-recolor\scripts\detect-colors.ps1 -PbipDir "C:\MyProject"

# Change all icons to red
.\svg-recolor\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#FF0000"
```

👉 **[Full Documentation](svg-recolor/README.md)**

## 📥 Installation

1. **Clone this repository**:
   ```powershell
   git clone https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
   cd powerbi-pbip-tools
   ```

2. **Requirements**:
   - Windows PowerShell 5.1+ or PowerShell Core 7+
   - A Power BI project in PBIP format

## 📚 Documentation

- [SVG Recolor Guide](docs/svg-recolor-guide.md) - Detailed tutorial
- [Example Project](examples/Demo/) - Working demo

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new tools
- Submit pull requests

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 👤 Author

**Cristobal Salcedo**
- Website: [csalcedodatabi.com](https://csalcedodatabi.com/)
- GitHub: [@CSalcedoDataBI](https://github.com/CSalcedoDataBI)
- LinkedIn: [Cristobal Salcedo](https://www.linkedin.com/in/cristobal-salcedo/)

---

⭐ If you find this useful, please star the repo!
