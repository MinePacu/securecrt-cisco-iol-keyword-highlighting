using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace InstallKeywordHighlightSetup;

internal static class Program
{
    // Keep in sync with Install-KeywordHighlight.ps1's $script:UpdateFileNames and launcher/Launcher.csproj (EmbeddedResource).
    private const string ScriptLogicalName = "Install-KeywordHighlight.ps1";
    private const string IniLogicalName = "PNET-Cisco-Dark.ini";
    private const string ChangelogLogicalName = "CHANGELOG.md";

    private static int Main(string[] args)
    {
        var assembly = typeof(Program).Assembly;

        string tempScriptPath;
        try
        {
            tempScriptPath = ExtractEmbeddedScript(assembly);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Failed to prepare the embedded installer script.");
            Console.Error.WriteLine(ex.Message);
            return 1;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            RedirectStandardOutput = false,
            RedirectStandardError = false,
            RedirectStandardInput = false,
        };
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(tempScriptPath);
        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        int exitCode;
        Process? process = null;
        try
        {
            try
            {
                process = Process.Start(psi);
            }
            catch (Win32Exception)
            {
                psi.FileName = "pwsh.exe";
                try
                {
                    process = Process.Start(psi);
                }
                catch (Win32Exception ex)
                {
                    Console.Error.WriteLine("Failed to launch powershell.exe or pwsh.exe.");
                    Console.Error.WriteLine("Make sure Windows PowerShell or PowerShell 7+ is installed and available on PATH.");
                    Console.Error.WriteLine($"Details: {ex.Message}");
                    return 1;
                }
            }

            if (process is null)
            {
                Console.Error.WriteLine("Failed to start powershell.exe: no process was created.");
                return 1;
            }

            process.WaitForExit();
            exitCode = process.ExitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("An unexpected error occurred while running the installer script.");
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
        finally
        {
            process?.Dispose();
        }

        if (args.Length == 0)
        {
            Console.WriteLine();
            Console.WriteLine("Press any key to continue...");
            Console.ReadKey(intercept: true);
        }

        return exitCode;
    }

    private static string ExtractEmbeddedScript(Assembly assembly)
    {
        var tempDirPath = Path.Combine(Path.GetTempPath(), "Install-KeywordHighlight-Setup");
        Directory.CreateDirectory(tempDirPath);

        var scriptPath = ExtractEmbeddedResource(assembly, ScriptLogicalName, tempDirPath);
        ExtractEmbeddedResource(assembly, IniLogicalName, tempDirPath);
        ExtractEmbeddedResource(assembly, ChangelogLogicalName, tempDirPath);

        return scriptPath;
    }

    private static string ExtractEmbeddedResource(Assembly assembly, string logicalName, string destinationDirPath)
    {
        var destinationPath = Path.Combine(destinationDirPath, logicalName);

        using var resourceStream = assembly.GetManifestResourceStream(logicalName);
        if (resourceStream is null)
        {
            var available = assembly.GetManifestResourceNames();
            var availableList = available.Length > 0 ? string.Join(", ", available) : "(none)";
            throw new InvalidOperationException(
                $"Embedded resource '{logicalName}' was not found in the assembly. " +
                $"Available resources: {availableList}");
        }

        using (var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            resourceStream.CopyTo(fileStream);
        }

        return destinationPath;
    }
}
