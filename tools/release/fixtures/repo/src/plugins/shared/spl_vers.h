// Miniature of src/plugins/shared/spl_vers.h for tools/release/test_release.py

#define VERSINFO_SALAMANDER_MAJOR 0
#define VERSINFO_SALAMANDER_MINORA 1
#define VERSINFO_SALAMANDER_MINORB 1

// Prehled pouzitych hodnot VERSINFO_BUILDNUMBER:
// 184 - Tandem Commander 0.1.0 (first release; see CHANGELOG.md)
// 185 - Tandem Commander 0.1.1 (SFTP key login no longer freezes - feature
//       011; see CHANGELOG.md)

// ! DULEZITE: nova cisla buildu je nutne zapsat do vetve "default", a pak
//             teprve do vedlejsi vetve (kompletni seznam je jen v "default" vetvi)
#define VERSINFO_BUILDNUMBER 185

//   105 - 0.1.0 build 184: the first interface
#define LAST_VERSION_OF_SALAMANDER 105
#define REQUIRE_LAST_VERSION_OF_SALAMANDER "This plugin requires a newer version of Tandem Commander: plugin interface 105, first shipped in version 0.1.0."
