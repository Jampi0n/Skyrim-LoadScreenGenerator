import os
import shutil
import pathlib
import time
import zipfile
import subprocess


class InstallOption:
    def __init__(self, name, description):
        self.files: [(str, str)] = []
        self.folders: [(str, str)] = []
        self.description = description
        self.name = name
        self.flags: [(str, str)] = []
        self.default = False
        self.image = ''

    def add_file(self, src, dest):
        self.files.append((src, dest))

    def add_folder(self, src, dest):
        self.folders.append((src, dest))

    def add_flag(self, flag_name, flag_value):
        self.flags.append((flag_name, flag_value))

    def set_default(self):
        self.default = True

    def add_image(self, path):
        self.image = os.path.join('fomod', path)


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
                if option.image != "":
                    self.write_line('<image path="' + option.image + '"/>')
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
                else:
                    self.write_line('<typeDescriptor>')
                    self.indent()
                    self.write_line('<type name="Optional"/>')
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
        self.sk_border_options = self.get_setting_key()
        self.sk_resolution = self.get_setting_key()
        self.sk_choose_border_option = self.get_setting_key()

        self.sk_generate_textures = self.get_setting_key()
        self.sk_generate_meshes = self.get_setting_key()
        self.sk_condition = self.get_setting_key()
        self.sk_condition_list = self.get_setting_key()

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
    images_path = os.path.join(os.getcwd(), "images")
    mesh_path = os.path.join(os.getcwd(), "meshes")
    script_path = os.path.join(os.getcwd(), "scripts")

    aspect_ratios = settings[settings.sk_aspect_ratios].split(",")
    messages = settings[settings.sk_messages]
    plugin_name = settings[settings.sk_plugin_name]
    frequency = settings[settings.sk_frequency]
    # frequencies = settings[settings.sk_frequency_list].split(",")
    # default_frequency = int(settings[settings.sk_default_frequency])
    condition = settings[settings.sk_condition]
    condition_list = settings[settings.sk_condition_list].split(",")
    condition_desc = {
        "standalone": "Both vanilla and custom loading screens will appear.",
        "replacer": "Custom loading screens have higher priorities, so vanilla loading screens will no longer appear.",
        "mcm": "Adds a Mod Configuration Menu that allows you to select the frequency at which custom loading screens will appear. Requires SKSE and SkyUI.",
        "fixed": "Custom loading screens will appear with a fixed frequency of " + str(frequency) + "%.",
        "test": "The loading screen that will appear depends on a global variable. Set the global variable to a specific value to force a specific loading screen.",
        "deprecated": "Implements the frequency using independent small probabilities. Unreliable, especially when a lot of custom loading screens exist.",
    }
    condition_scripts = ["mcm", "fixed"]
    add_scripts_to_fomod = False
    for cond in condition_list:
        if cond in condition_scripts:
            add_scripts_to_fomod = True
    default_border_option = settings[settings.sk_border_options]
    border_options = ['black', 'crop', 'stretch', 'fullheight', 'fullwidth']
    border_option_names = ['Black', 'Crop', 'Stretch', 'Full Height', 'Full Width']
    border_option_descriptions = [
        'Uses letterboxes (top and bottom black bars) and pillarboxes (left and right black bars) to fit the image to the screen aspect ratio.',
        'Crops the image to fit it to the screen aspect ratio. The parts of the image that lie outside the screen are not displayed, effectively cropping the image.',
        'Stretches the image to fit it to the screen aspect ratio. Not recommended. Will distort images.',
        'Uses pillarboxes (left and right black bars) or horizontal cropping to fit the image to the screen aspect ratio. The parts of the image that lie outside the screen are not displayed, effectively cropping the image.',
        'Uses letterboxes (top and bottom black bars) or vertical cropping to fit the image to the screen aspect ratio. The parts of the image that lie outside the screen are not displayed, effectively cropping the image.',
    ]

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

    if add_scripts_to_fomod:
        script_folder = os.path.join(fomod_folder, "scripts")
        shutil.copytree(script_path, script_folder)

    safe_make_directory(os.path.join(fomod_folder, "messages"))
    safe_make_directory(os.path.join(fomod_folder, "no_messages"))
    safe_make_directory(os.path.join(fomod_folder, "fomod"))

    for cond in condition_list:
        safe_make_directory(os.path.join(fomod_folder, "messages", cond))
        safe_make_directory(os.path.join(fomod_folder, "no_messages", cond))

    # Move files
    shutil.copytree(texture_path, os.path.join(main_folder, "textures"))
    shutil.copytree(images_path, os.path.join(fomod_folder, "fomod", "images"))
    for aspect_ratio in aspect_ratios:
        if settings[settings.sk_choose_border_option]:
            for opt in border_options:
                fomod_mesh_path = os.path.join(fomod_folder, aspect_ratio, opt, "meshes")
                shutil.copytree(os.path.join(mesh_path, aspect_ratio, opt), fomod_mesh_path)
                safe_make_directory(os.path.join(fomod_mesh_path, "_mesh_option_" + str(aspect_ratio) + "_" + str(opt)))
        else:
            fomod_mesh_path = os.path.join(fomod_folder, aspect_ratio, default_border_option, "meshes")
            shutil.copytree(os.path.join(mesh_path, aspect_ratio, default_border_option), fomod_mesh_path)
            safe_make_directory(os.path.join(fomod_mesh_path, "_mesh_option_" + str(aspect_ratio) + "_" + str(default_border_option)))

    for cond in condition_list:
        plugin = "../FOMOD_M0" + "_P_" + cond + "_" + str(frequency) + "_FOMODEND_" + plugin_name
        if os.path.exists(plugin):
            fomod_plugin_path = os.path.join(fomod_folder, "no_messages", cond)
            shutil.copy(plugin, os.path.join(fomod_plugin_path, plugin_name))
            safe_make_directory(os.path.join(fomod_plugin_path, "_plugin_option_no_messages_" + cond))

        plugin = "../FOMOD_M1" + "_P_" + cond + "_" + str(frequency) + "_FOMODEND_" + plugin_name
        if os.path.exists(plugin):
            fomod_plugin_path = os.path.join(fomod_folder, "messages", cond)
            shutil.copy(plugin, os.path.join(fomod_plugin_path, plugin_name))
            safe_make_directory(os.path.join(fomod_plugin_path, "_plugin_option_messages_" + cond))

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

    # textures
    fomod.add_required_folder('main', '')

    # meshes
    if len(aspect_ratios) > 1:
        choose_aspect_ratio = InstallStep('Aspect Ratio')
        fomod.add_install_step(choose_aspect_ratio)
        for aspect_ratio in aspect_ratios:
            ratio_option = InstallOption(aspect_ratio,
                                         'Use this option, if you have an aspect ratio of ' + aspect_ratio + '.')
            if settings[settings.sk_choose_border_option]:
                ratio_option.add_flag('aspect_ratio_' + aspect_ratio, 'true')
                choose_border_option = InstallStep('Border Options')

                k = 0
                for opt in border_options:
                    border_install_options = InstallOption(border_option_names[k], border_option_descriptions[k])
                    border_install_options.add_folder(os.path.join(aspect_ratio, opt), '')
                    border_install_options.add_image(os.path.join('images', opt + '.png'))
                    if opt == default_border_option:
                        border_install_options.set_default()
                    choose_border_option.add_option(border_install_options)
                    k += 1

                choose_border_option.require_flag('aspect_ratio_' + aspect_ratio, 'true')
                fomod.add_install_step(choose_border_option)
            else:
                ratio_option.add_folder(os.path.join(aspect_ratio, default_border_option), '')
            choose_aspect_ratio.add_option(ratio_option)
    else:
        if settings[settings.sk_choose_border_option]:
            aspect_ratio = aspect_ratios[0]
            choose_border_option = InstallStep('Border Options')

            k = 0
            for opt in border_options:
                border_install_options = InstallOption(border_option_names[k], border_option_descriptions[k])
                border_install_options.add_folder(os.path.join(aspect_ratio, opt), '')
                border_install_options.add_image(os.path.join('images', opt + '.png'))
                if opt == default_border_option:
                    border_install_options.set_default()
                choose_border_option.add_option(border_install_options)
                k += 1

            fomod.add_install_step(choose_border_option)
        else:
            fomod.add_required_folder(os.path.join(aspect_ratios[0], default_border_option), '')

    # plugin
    if messages == 'optional':
        choose_messages = InstallStep('Display Messages')
        yes = InstallOption('Yes', 'Enables loading screen messages.')
        yes.add_flag('loading_screen_messages', 'true')
        no = InstallOption('No', 'Disables loading screen messages.')
        no.add_flag('loading_screen_messages', 'false')
        choose_messages.add_option(yes)
        choose_messages.add_option(no)
        fomod.add_install_step(choose_messages)

        if len(condition_list) == 1:
            yes.add_folder(os.path.join('messages', condition_list[0]), '')
            no.add_folder(os.path.join('no_messages', condition_list[0]), '')
            if condition_list[0] in condition_scripts:
                yes.add_folder('scripts', 'scripts')
                no.add_folder('scripts', 'scripts')

    if messages == 'always' and len(condition_list) == 1:
        fomod.add_required_folder(os.path.join('messages', condition_list[0]), '')
        if condition_list[0] in condition_scripts:
            fomod.add_required_folder('scripts', 'scripts')

    if messages == 'never' and len(condition_list) == 1:
        fomod.add_required_folder(os.path.join('no_messages', condition_list[0]), '')
        if condition_list[0] in condition_scripts:
            fomod.add_required_folder('scripts', 'scripts')

    if len(condition_list) > 1:
        choose_frequency_yes = InstallStep('Loading Screen Frequency')
        choose_frequency_no = InstallStep('Loading Screen Frequency')

        for cond in condition_list:
            desc = condition_desc[cond]

            freq_option_yes = InstallOption(cond, desc)
            freq_option_yes.add_folder(os.path.join('messages', cond), '')
            choose_frequency_yes.add_option(freq_option_yes)

            freq_option_no = InstallOption(cond, desc)
            freq_option_no.add_folder(os.path.join('no_messages', cond), '')
            choose_frequency_no.add_option(freq_option_no)

            if cond in condition_scripts:
                freq_option_yes.add_folder('scripts', 'scripts')
                freq_option_no.add_folder('scripts', 'scripts')

            if cond == condition:
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

    # finalize
    fomod.write_file()
    module_config_xml.close()
    zip_path_7z = mod_name + '_' + mod_version + '.7z'
    zip_path_zip = mod_name + '_' + mod_version + '.zip'
    zip_path_7z = os.path.join(os.getcwd(), zip_path_7z)

    try:
        result = subprocess.run('7z i', stdout=subprocess.PIPE)
    except FileNotFoundError:
        result = ''

    if '7z' in str(result.stdout):
        cwd = os.getcwd()
        os.chdir(os.path.join(cwd, 'fomod'))
        subprocess.run('7z a "' + zip_path_7z + '" .\\* -mx')
        os.chdir(cwd)
    else:
        with zipfile.ZipFile(zip_path_zip, 'w') as zip_file:
            for root, dirs, files in os.walk(fomod_folder, topdown=False):
                for name in files:
                    path = os.path.join(root, name)
                    rel_path = os.path.relpath(path, fomod_folder)
                    print(path)
                    print(rel_path)
                    zip_file.write(path, rel_path)


if __name__ == '__main__':
    main()
