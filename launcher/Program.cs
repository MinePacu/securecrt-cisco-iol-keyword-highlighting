using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

namespace InstallKeywordHighlightSetup;

internal static class Program
{
    private const string ScriptLogicalName = "Install-KeywordHighlight.ps1";

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

        var passthroughArgs = BuildArgumentString(args);

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\"{passthroughArgs}",
            UseShellExecute = false,
            RedirectStandardOutput = false,
            RedirectStandardError = false,
            RedirectStandardInput = false,
        };

        int exitCode;
        try
        {
            using var process = Process.Start(psi);
            if (process is null)
            {
                Console.Error.WriteLine("Failed to start powershell.exe: no process was created.");
                return 1;
            }

            process.WaitForExit();
            exitCode = process.ExitCode;
        }
        catch (Win32Exception ex)
        {
            Console.Error.WriteLine("Failed to launch powershell.exe.");
            Console.Error.WriteLine("Make sure Windows PowerShell is installed and available on PATH.");
            Console.Error.WriteLine($"Details: {ex.Message}");
            return 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("An unexpected error occurred while running the installer script.");
            Console.Error.WriteLine(ex.Message);
            return 1;
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
        using var resourceStream = assembly.GetManifestResourceStream(ScriptLogicalName);
        if (resourceStream is null)
        {
            var available = assembly.GetManifestResourceNames();
            var availableList = available.Length > 0 ? string.Join(", ", available) : "(none)";
            throw new InvalidOperationException(
                $"Embedded resource '{ScriptLogicalName}' was not found in the assembly. " +
                $"Available resources: {availableList}");
        }

        var tempScriptPath = Path.Combine(Path.GetTempPath(), "Install-KeywordHighlight-Setup.ps1");

        using (var fileStream = new FileStream(tempScriptPath, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            resourceStream.CopyTo(fileStream);
        }

        return tempScriptPath;
    }

    private static string BuildArgumentString(string[] args)
    {
        if (args.Length == 0)
        {
            return string.Empty;
        }

        var sb = new StringBuilder();
        foreach (var arg in args)
        {
            sb.Append(' ');
            sb.Append(QuoteArgument(arg));
        }

        return sb.ToString();
    }

    // Quotes a single argument for the Windows command line in a way that
    // survives both the C# ProcessStartInfo.Arguments parser and
    // PowerShell's own argument parsing.
    private static string QuoteArgument(string arg)
    {
        if (arg.Length > 0 && arg.IndexOfAny(new[] { ' ', '\t', '"' }) < 0)
        {
            return arg;
        }

        var sb = new StringBuilder();
        sb.Append('"');
        for (var i = 0; i < arg.Length; i++)
        {
            var c = arg[i];
            if (c == '"')
            {
                sb.Append('\\');
            }
            sb.Append(c);
        }
        sb.Append('"');
        return sb.ToString();
    }
}
