#nullable enable
using System.Collections.Generic;
using System.CommandLine;
using System.IO;
using System.Threading.Tasks;
using DafnyDriver.Commands;
using Microsoft.Dafny.Compilers;

namespace Microsoft.Dafny;

public static class BakeCommand {
  public static Command Create() {

    var result = new Command("bake", "Generates an S-Expression for the Dafny to CakeML compiler.");

    result.AddArgument(Target);
    result.AddArgument(DafnyCommands.FileArgument);
    foreach (var option in ExtractOptions) {
      result.AddOption(option);
    }

    DafnyNewCli.SetHandlerUsingDafnyOptionsContinuation(result, (options, _) => HandleExtraction(options));
    return result;
  }

  private static readonly Argument<FileInfo> Target = new("The path of the extracted file.");

  private static IReadOnlyList<Option> ExtractOptions =>
    new Option[] { }.
      Concat(DafnyCommands.ConsoleOutputOptions).
      Concat(DafnyCommands.ResolverOptions);

  public static async Task<int> HandleExtraction(DafnyOptions options) {
    if (options.Get(CommonOptionBag.VerificationCoverageReport) != null) {
      options.TrackVerificationCoverage = true;
    }

    var compilation = CliCompilation.Create(options);
    compilation.Start();

    var resolution = await compilation.Resolution;
    if (resolution is not { HasErrors: false }) {
      return await compilation.GetAndReportExitCode();
    }

    var outputPath = options.Get(Target).FullName;
    try {
      var extractedProgram = Bake.ProgramToString(resolution.ResolvedProgram);
      File.WriteAllText(outputPath, extractedProgram);
    } catch (ExtractorError extractorError) {
      var tok = extractorError.Tok;
      await options.OutputWriter.WriteLineAsync($"{tok.filename}({tok.line},{tok.col}): S-expression extraction error: {extractorError.Message}");
      return 1;
    }

    return await compilation.GetAndReportExitCode();
  }
}