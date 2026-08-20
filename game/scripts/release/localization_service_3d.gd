class_name LocalizationService3D
extends Node

signal locale_changed(locale: StringName)

const CATALOG_PATHS: Dictionary = {
    &"en": "res://localization/en.json",
    &"sv": "res://localization/sv.json",
    &"de": "res://localization/de.json",
}

var current_locale: StringName = &"en"
var catalogs: Dictionary = {}
var language_names: Dictionary = {}
var load_errors: Array[String] = []


func _ready() -> void:
    add_to_group(&"localization_service")
    _load_catalogs()


func _load_catalogs() -> void:
    catalogs.clear()
    language_names.clear()
    load_errors.clear()
    for raw_locale in CATALOG_PATHS:
        var locale := raw_locale as StringName
        var path := str(CATALOG_PATHS[locale])
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null:
            load_errors.append("Missing localization catalog: %s" % path)
            continue
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if not (parsed is Dictionary):
            load_errors.append("Invalid localization catalog: %s" % path)
            continue
        var data := parsed as Dictionary
        var strings: Variant = data.get("strings", {})
        if not (strings is Dictionary):
            load_errors.append("Localization catalog has no strings object: %s" % path)
            continue
        catalogs[locale] = (strings as Dictionary).duplicate(true)
        language_names[locale] = str(data.get("language_name", String(locale)))
    if not catalogs.has(&"en"):
        catalogs[&"en"] = {}
        language_names[&"en"] = "English"


func set_locale(locale: StringName) -> bool:
    if not catalogs.has(locale):
        return false
    if current_locale == locale:
        return true
    current_locale = locale
    locale_changed.emit(current_locale)
    return true


func text(key: String, replacements: Array = []) -> String:
    var current: Dictionary = catalogs.get(current_locale, {})
    var fallback: Dictionary = catalogs.get(&"en", {})
    var value := str(current.get(key, fallback.get(key, key)))
    for index in range(replacements.size()):
        value = value.replace("{%d}" % index, str(replacements[index]))
    return value


func available_locales() -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_locale in catalogs:
        result.append(raw_locale as StringName)
    result.sort_custom(func(a: StringName, b: StringName) -> bool:
        return str(language_names.get(a, String(a))) < str(language_names.get(b, String(b)))
    )
    return result


func language_name(locale: StringName) -> String:
    return str(language_names.get(locale, String(locale)))


func catalog_keys(locale: StringName) -> Array[String]:
    var result: Array[String] = []
    var catalog: Dictionary = catalogs.get(locale, {})
    for raw_key in catalog:
        result.append(str(raw_key))
    result.sort()
    return result


func catalogs_have_parity() -> bool:
    var baseline := catalog_keys(&"en")
    for locale in available_locales():
        if catalog_keys(locale) != baseline:
            return false
    return true
