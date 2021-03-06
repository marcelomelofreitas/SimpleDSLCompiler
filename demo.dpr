program demo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DSiWin32,
  SimpleDSLCompiler in 'SimpleDSLCompiler.pas',
  SimpleDSLCompiler.Parser in 'SimpleDSLCompiler.Parser.pas',
  SimpleDSLCompiler.AST in 'SimpleDSLCompiler.AST.pas',
  SimpleDSLCompiler.Runnable in 'SimpleDSLCompiler.Runnable.pas',
  SimpleDSLCompiler.Compiler in 'SimpleDSLCompiler.Compiler.pas',
  SimpleDSLCompiler.ErrorInfo in 'SimpleDSLCompiler.ErrorInfo.pas',
  SimpleDSLCompiler.Base in 'SimpleDSLCompiler.Base.pas',
  SimpleDSLCompiler.Tokenizer in 'SimpleDSLCompiler.Tokenizer.pas',
  SimpleDSLCompiler.Compiler.Dump in 'SimpleDSLCompiler.Compiler.Dump.pas',
  SimpleDSLCompiler.Compiler.Codegen in 'SimpleDSLCompiler.Compiler.Codegen.pas',
  SimpleDSLCompiler.Interpreter in 'SimpleDSLCompiler.Interpreter.pas';

const
  CMultiProcCode =
    'fib(i) [memo] {                   '#13#10 +
    '  if i < 3 {                      '#13#10 +
    '    return 1                      '#13#10 +
    '  } else {                        '#13#10 +
    '    return fib(i-2) + fib(i-1)    '#13#10 +
    '  }                               '#13#10 +
    '}                                 '#13#10 +
    '                                  '#13#10 +
    'mult(a,b) {                       '#13#10 +
    '  if b < 2 {                      '#13#10 +
    '    return a                      '#13#10 +
    '  } else {                        '#13#10 +
    '    return mult(a, b-1) + a       '#13#10 +
    '  }                               '#13#10 +
    '}                                 '#13#10 +
    '                                  '#13#10 +
    'power(a,b) {                      '#13#10 +
    '  if b < 2 {                      '#13#10 +
    '    return a                      '#13#10 +
    '  }                               '#13#10 +
    '  else {                          '#13#10 +
    '    return mult(power(a, b-1), a) '#13#10 +
    '  }                               '#13#10 +
    '}                                 '#13#10;

var
  compiler   : ISimpleDSLCompiler;
  exec       : ISimpleDSLProgram;
  fibComp    : TFunctionCall;
  interpreter: ISimpleDSLProgram;
  res        : integer;
  sl         : TStringList;
  time       : int64;

function fib(i: integer): integer;
begin
  if i < 3 then
    Result := 1
  else
    Result := fib(i-2) + fib(i-1);
end;

begin
  try
    sl := TStringList.Create;
    try
      compiler := CreateSimpleDSLCompiler;
      compiler.CodegenFactory := function: ISimpleDSLCodegen begin Result := CreateSimpleDSLCodegenDump(sl); end;
      compiler.Compile(CMultiProcCode);
      Writeln(sl.Text);
    finally FreeAndNil(sl); end;

    compiler := CreateSimpleDSLCompiler;
    if not compiler.Compile(CMultiProcCode) then
      Writeln('Compilation/codegen error: ' + (compiler as ISimpleDSLErrorInfo).ErrorInfo)
    else begin
      exec := compiler.Code;
      if exec.Call('mult', [5,3], res) then
        Writeln('mult(5,3) = ', res)
      else
        Writeln('mult: ' + (exec as ISimpleDSLErrorInfo).ErrorInfo);

      Writeln('2^10 = ', exec.Make('power')([2,10]));

      fibComp := exec.Make('fib');

      Writeln(fib(7));
      Writeln(fibComp([7]));

      time := DSiTimeGetTime64;
      res := fib(30);
      time := DSiElapsedTime64(time);
      Writeln('Native: ', res, ' in ', time, ' ms');

      time := DSiTimeGetTime64;
      res := fibComp([30]);
      time := DSiElapsedTime64(time);
      Writeln('Compiled: ', res, ' in ', time, ' ms');

      interpreter := CreateSimpleDSLInterpreter(compiler.AST);
      time := DSiTimeGetTime64;
      res := 0;
      if not interpreter.Call('fib', [30], res) then
        Writeln('interpreter: ' + (interpreter as ISimpleDSLErrorInfo).ErrorInfo)
      else begin
        time := DSiElapsedTime64(time);
        Writeln('Interpreted: ', res, ' in ', time, ' ms');
      end;
    end;

    Write('> ');
    Readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
