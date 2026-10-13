using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Roblox Performance Setup")]
[assembly: AssemblyProduct("Roblox Performance")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Setup {
    [STAThread]
    private static int Main(string[] args) {
        bool quiet = args.Length == 1 && args[0] == "--quiet";
        string destination = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RobloxPerformance");
        bool extractOnly = args.Length == 2 && args[0] == "--extract-only";
        if (extractOnly) destination = Path.GetFullPath(args[1]);
        else if (args.Length != 0 && !quiet) return 2;
        try {
            if (!quiet && !extractOnly && MessageBox.Show(
                "Install Roblox Performance and desktop shortcuts?\n\nEnables Windows Game Mode, disables historical game recording, and selects High Performance power where available. Launchers use minimum Roblox graphics at 720p with a 60 FPS cap. Saves settings for restoration.\n\nThis does not guarantee stable 60 FPS. Close Roblox before using a launcher.",
                "Roblox Performance Setup 1.0.0", MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK) return 0;
            Directory.CreateDirectory(destination);
            using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("Payload.zip")) {
                if (payload == null) throw new InvalidOperationException("Missing embedded payload.");
                using (ZipArchive zip = new ZipArchive(payload, ZipArchiveMode.Read)) {
                    foreach (ZipArchiveEntry entry in zip.Entries) {
                        string name = entry.FullName;
                        if (String.IsNullOrEmpty(name) || name != Path.GetFileName(name) || name.IndexOf(':') >= 0 || name.IndexOf('\\') >= 0 || name.IndexOf('/') >= 0 || entry.Length > 5242880)
                            throw new InvalidDataException("Invalid payload entry.");
                        string extension = Path.GetExtension(name).ToLowerInvariant();
                        if (extension != ".ps1" && extension != ".cmd" && extension != ".md") throw new InvalidDataException("Unsupported payload file.");
                        string target = Path.Combine(destination, name);
                        string temporary = target + ".setup-" + Guid.NewGuid().ToString("N") + ".tmp";
                        try {
                            using (Stream input = entry.Open())
                            using (FileStream output = File.Create(temporary)) input.CopyTo(output);
                            if (File.Exists(target)) File.Replace(temporary, target, null);
                            else File.Move(temporary, target);
                        } finally { if (File.Exists(temporary)) File.Delete(temporary); }
                    }
                }
            }
            if (extractOnly) return 0;
            string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            ProcessStartInfo start = new ProcessStartInfo(Path.Combine(windows, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"));
            start.Arguments = "-NoProfile -ExecutionPolicy RemoteSigned -File \"" + Path.Combine(destination, "Install-Profile.ps1") + "\"";
            start.WorkingDirectory = destination;
            start.EnvironmentVariables["PSModulePath"] = Path.Combine(windows, "System32", "WindowsPowerShell", "v1.0", "Modules");
            start.UseShellExecute = false;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            start.CreateNoWindow = true;
            start.WindowStyle = ProcessWindowStyle.Hidden;
            using (Process process = Process.Start(start)) {
                var output = process.StandardOutput.ReadToEndAsync();
                var error = process.StandardError.ReadToEndAsync();
                process.WaitForExit();
                string report = output.GetAwaiter().GetResult() + "\r\n" + error.GetAwaiter().GetResult();
                File.WriteAllText(Path.Combine(destination, "setup-last.log"), report);
                if (process.ExitCode != 0) throw new InvalidOperationException("Installation failed. See " + Path.Combine(destination, "setup-last.log") + "\n\n" + report);
                if (!quiet) MessageBox.Show(report, "Roblox Performance installed", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            return 0;
        } catch (Exception error) {
            if (!quiet && !extractOnly) MessageBox.Show(error.Message, "Roblox Performance setup error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            try { File.WriteAllText(Path.Combine(destination, "setup-error.log"), error.ToString()); } catch { }
            return 1;
        }
    }
}
