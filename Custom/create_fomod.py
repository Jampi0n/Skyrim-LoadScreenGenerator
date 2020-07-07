import os
import shutil
import pathlib
import time
import zipfile


class InstallOption:
    def __init__(self, name, description):
        self.files: [(str, str)] = []
        self.folders: [(str, str)] = []
        self.description = description
        self.name = name
        self.flags: [(str, str)] = []
        self.default = False

    def add_file(self, src, dest):
        self.files.append((src, dest))

    def add_folder(self, src, dest):
        self.folders.append((src, dest))

    def add_flag(self, flag_name, flag_value):
        self.flags.append((flag_name, flag_value))

    def set_default(self):
        self.default = True


class InstallStep:
    def __init__(self, name):
        self.name = name
        self.options: [InstallOption] = []
        self.required_flags: [(str, str)] = []

    def require_flag(self, flag_name, flag_value):
        self.required_flags.append((flag_name, flag_value))

    def add_option(self, option):
        self.options.append(option)


class Fomod:
    def __init__(self, file_handle, name):
        self.file_handle = file_handle
        self.module_name = name
        self.indentation_level = 0
        self.install_steps: [InstallStep] = []
        self.required_files: [(str, str)] = []
        self.required_folders: [(str, str)] = []

    def add_required_file(self, src, dest):
        self.required_files.append((src, dest))

    def add_required_folder(self, src, dest):
        self.required_folders.append((src, dest))

    def add_install_step(self, step):
        self.install_steps.append(step)

    def indent(self):
        self.indentation_level += 1

    def unindent(self):
        self.indentation_level -= 1

    def write_line(self, line):
        indentation = ""
        for i in range(self.indentation_level):
            indentation += "\t"
        self.file_handle.write(indentation + line + "\n")

    def write_file(self):
        self.write_line(
            '<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://qconsulting.ca/fo3/ModConfig5.0.xsd"> ')
        self.indent()
        self.write_line('<moduleName>' + self.module_name + '</moduleName>')

        self.write_line('<requiredInstallFiles>')
        self.indent()
        for src, dest in self.required_files:
            self.write_line('<file source="' + src + '" destination="' + dest + '" priority="0" />')
        for src, dest in self.required_folders:
            self.write_line('<folder source="' + src + '" destination="' + dest + '" priority="0" />')
        self.unindent()
        self.write_line('</requiredInstallFiles>')

        self.write_line('<installSteps order="Explicit">')
        self.indent()
        for install_step in self.install_steps:
            self.write_line('<installStep name="' + install_step.name + '">')
            self.indent()
            if len(install_step.required_flags) > 0:
                self.write_line('<visible>')
                for flag_name, flag_value in install_step.required_flags:
                    self.write_line('<flagDependency flag="' + flag_name + '" value="' + flag_value + '"/>')
                self.write_line('</visible>')

            self.write_line('<optionalFileGroups order="Explicit">')
            self.indent()
            self.write_line('<group name="' + install_step.name + '" type="SelectExactlyOne">')
            self.indent()
            self.write_line('<plugins order="Explicit">')
            self.indent()
            for option in install_step.options:
                self.write_line('<plugin name="' + option.name + '">')
                self.indent()
                self.write_line('<description>' + option.description + '</description>')
                if len(option.files) + len(option.folders) > 0:
                    self.write_line('<files>')
                    self.indent()
                    for src, dest in option.files:
                        self.write_line('<file source="' + src + '" destination="' + dest + '" priority="0" />')
                    for src, dest in option.folders:
                        self.write_line('<folder source="' + src + '" destination="' + dest + '" priority="0" />')
                    self.unindent()
                    self.write_line('</files>')

                if len(option.flags) > 0:
                    self.write_line('<conditionFlags>')
                    self.indent()
                    for flag_name, flag_value in option.flags:
                        self.write_line('<flag name="' + flag_name + '">' + flag_value + '</flag>')
                    self.unindent()
                    self.write_line('</conditionFlags>')

                if option.default:
                    self.write_line('<typeDescriptor>')
                    self.indent()
                    self.write_line('<type name="Recommended"/>')
                    self.unindent()
                    self.write_line('</typeDescriptor>')

                self.unindent()
                self.write_line('</plugin>')
            self.unindent()
            self.write_line('</plugins>')
            self.unindent()
            self.write_line('</group>')
            self.unindent()
            self.write_line('</optionalFileGroups>')
            self.unindent()
            self.write_line('</installStep>')
        self.unindent()
        self.write_line('</installSteps>')
        self.unindent()
        self.write_line('</config>')


class Settings:
    def __init__(self):
        self.setting_key = 0

        self.settings_file = open(os.path.join(os.getcwd(), "settings.txt"), "r")
        tmp = self.settings_file.readlines()
        self.settings_array = []
        for line in tmp:
            if line.endswith('\n'):
                line = line[:-1]
            self.settings_array.append(line)

        self.sk_source_path = self.get_setting_key()
        self.sk_disable_other_load_screens = self.get_setting_key()
        self.sk_display_width = self.get_setting_key()
        self.sk_display_height = self.get_setting_key()
        self.sk_stretch = self.get_setting_key()
        self.sk_recursive = self.get_setting_key()

        self.sk_gamma = self.get_setting_key()
        self.sk_contrast = self.get_setting_key()

        self.sk_brightness = self.get_setting_key()
        self.sk_saturation = self.get_setting_key()

        self.sk_full_height = self.get_setting_key()
        self.sk_test_mode = self.get_setting_key()
        self.sk_frequency = self.get_setting_key()

        self.sk_mod_name = self.get_setting_key()
        self.sk_mod_version = self.get_setting_key()
        self.sk_mod_folder = self.get_setting_key()
        self.sk_plugin_name = self.get_setting_key()
        self.sk_mod_author = self.get_setting_key()
        self.sk_prefix = self.get_setting_key()
        self.sk_aspect_ratios = self.get_setting_key()
        self.sk_texture_resolutions = self.get_setting_key()
        self.sk_messages = self.get_setting_key()
        self.sk_frequency_list = self.get_setting_key()
        self.sk_default_frequency = self.get_setting_key()
        self.sk_mod_link = self.get_setting_key()

    def get_setting_key(self):
        self.setting_key += 1
        return self.setting_key - 1

    def __getitem__(self, item):
        return self.read_setting(item)

    def read_setting(self, setting_key):
        return self.settings_array[setting_key]


def safe_make_directory(path):
    pathlib.Path(path).mkdir(parents=True, exist_ok=True)


def main():
    print(os.getcwd())
    settings = Settings()

    texture_path = os.path.join(os.getcwd(), "textures")
    mesh_path = os.path.join(os.getcwd(), "meshes")

    aspect_ratios = settings[settings.sk_aspect_ratios].split(",")
    messages = settings[settings.sk_messages]
    plugin_name = settings[settings.sk_plugin_name]
    frequencies = settings[settings.sk_frequency_list].split(",")
    default_frequency = int(settings[settings.sk_default_frequency])

    mod_name = settings[settings.sk_mod_name]
    mod_version = settings[settings.sk_mod_version]
    mod_author = settings[settings.sk_mod_author]
    mod_desc = "description"
    mod_link = settings[settings.sk_mod_link]

    print(aspect_ratios)
    print(messages)

    # Create folder structure

    fomod_folder = os.path.join(os.getcwd(), "fomod")
    if os.path.exists(fomod_folder):
        shutil.rmtree(fomod_folder)
        time.sleep(0.25)

    main_folder = os.path.join(fomod_folder, "main")

    safe_make_directory(fomod_folder)
    safe_make_directory(main_folder)
    for aspect_ratio in aspect_ratios:
        safe_make_directory(os.path.join(fomod_folder, aspect_ratio))

    safe_make_directory(os.path.join(fomod_folder, "messages"))
    safe_make_directory(os.path.join(fomod_folder, "no_messages"))
    safe_make_directory(os.path.join(fomod_folder, "fomod"))

    for freq in frequencies:
        safe_make_directory(os.path.join(fomod_folder, "messages", "p" + str(freq)))
        safe_make_directory(os.path.join(fomod_folder, "no_messages", "p" + str(freq)))

    # Move files
    shutil.copytree(texture_path, os.path.join(main_folder, "textures"))
    for aspect_ratio in aspect_ratios:
        shutil.copytree(os.path.join(mesh_path, aspect_ratio), os.path.join(fomod_folder, aspect_ratio, "meshes"))

    for p in frequencies:
        plugin = "FOMOD_M0" + "_P" + str(p) + "_FOMODEND_" + plugin_name
        if os.path.exists(plugin):
            shutil.copy(plugin, os.path.join(fomod_folder, "no_messages", "p" + str(p), plugin_name))

        plugin = "FOMOD_M1" + "_P" + str(p) + "_FOMODEND_" + plugin_name
        if os.path.exists(plugin):
            shutil.copy(plugin, os.path.join(fomod_folder, "messages", "p" + str(p), plugin_name))

    info_xml = open(os.path.join(fomod_folder, "fomod", "info.xml"), "w")
    info_xml.writelines([
        "<fomod>\n",
        "   <Name>" + mod_name + "</Name>\n",
        "   <Author>" + mod_author + "</Author>\n",
        "   <Version>" + mod_version + "</Version>\n",
        "   <Website>" + mod_link + "</Website>\n",
        "   <Description>" + mod_desc + "</Description>\n",
        "</fomod>\n"
    ])
    info_xml.close()

    module_config_xml = open(os.path.join(fomod_folder, "fomod", "ModuleConfig.xml"), "w")
    fomod = Fomod(module_config_xml, mod_name)

    fomod.add_required_folder('main', '')

    if len(aspect_ratios) > 1:
        choose_aspect_ratio = InstallStep('Aspect Ratio')
        for aspect_ratio in aspect_ratios:
            ratio_option = InstallOption(aspect_ratio,
                                         'Use this option, if you have an aspect ratio of ' + aspect_ratio + '.')
            ratio_option.add_folder(aspect_ratio, '')
            choose_aspect_ratio.add_option(ratio_option)
        fomod.add_install_step(choose_aspect_ratio)
    else:
        fomod.add_required_folder(aspect_ratios[0], '')

    if messages == 'optional':
        choose_messages = InstallStep('Display Messages')
        yes = InstallOption('Yes', 'Enables loading screen messages.')
        yes.add_flag('loading_screen_messages', 'true')
        no = InstallOption('No', 'Disables loading screen messages.')
        no.add_flag('loading_screen_messages', 'false')
        choose_messages.add_option(yes)
        choose_messages.add_option(no)
        fomod.add_install_step(choose_messages)

        if len(frequencies) == 1:
            yes.add_folder(os.path.join('messages', 'p' + str(frequencies[0])), '')
            no.add_folder(os.path.join('no_messages', 'p' + str(frequencies[0])), '')

    if messages == 'always' and len(frequencies) == 1:
        fomod.add_required_folder(os.path.join('messages', 'p' + str(frequencies[0])), '')

    if messages == 'never' and len(frequencies) == 1:
        fomod.add_required_folder(os.path.join('no_messages', 'p' + str(frequencies[0])), '')

    if len(frequencies) > 1:
        choose_frequency_yes = InstallStep('Loading Screen Frequency')
        choose_frequency_no = InstallStep('Loading Screen Frequency')

        for freq in frequencies:
            desc = 'Controls how often the loading screens appear. With a frequency of 100%, ' \
                   'loading screens from vanilla and vanilla compatible loading screen mods will no longer be used.'

            freq_option_yes = InstallOption(str(freq) + '%', desc)

            freq_option_yes.add_folder(os.path.join('messages', 'p' + str(freq)), '')
            choose_frequency_yes.add_option(freq_option_yes)

            freq_option_no = InstallOption(str(freq) + '%', desc)
            freq_option_no.add_folder(os.path.join('no_messages', 'p' + str(freq)), '')
            choose_frequency_no.add_option(freq_option_no)

            if int(freq) == default_frequency:
                freq_option_yes.set_default()
                freq_option_no.set_default()

        if messages == 'optional':
            choose_frequency_yes.require_flag('loading_screen_messages', 'true')
            choose_frequency_no.require_flag('loading_screen_messages', 'false')
            fomod.add_install_step(choose_frequency_yes)
            fomod.add_install_step(choose_frequency_no)

        if messages == 'always':
            fomod.add_install_step(choose_frequency_yes)

        if messages == 'never':
            fomod.add_install_step(choose_frequency_no)

    fomod.write_file()
    module_config_xml.close()

    zip_path = mod_name + '_' + mod_version + '.zip'

    with zipfile.ZipFile(zip_path, 'w') as zip_file:
        for root, dirs, files in os.walk(fomod_folder, topdown=False):
            for name in files:
                path = os.path.join(root, name)
                rel_path = os.path.relpath(path, fomod_folder)
                print(path)
                print(rel_path)
                zip_file.write(path, rel_path)


if __name__ == '__main__':
    main()
