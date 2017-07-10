unit SimpleDSLCompiler.Parser;

interface

uses
  SimpleDSLCompiler.Tokenizer,
  SimpleDSLCompiler.AST;

type
  ISimpleDSLParser = interface ['{73F3CBB3-3DEF-4573-B079-7EFB00631560}']
    function Parse(const code: string; const tokenizer: ISimpleDSLTokenizer;
      const ast: ISimpleDSLAST): boolean;
  end; { ISimpleDSLParser }

  TSimpleDSLParserFactory = reference to function: ISimpleDSLParser;

function CreateSimpleDSLParser: ISimpleDSLParser;

implementation

uses
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  SimpleDSLCompiler.Base,
  SimpleDSLCompiler.ErrorInfo;

type
  TTokenKinds = set of TTokenKind;

  TSimpleDSLParser = class(TSimpleDSLCompilerBase, ISimpleDSLParser)
  strict private
    FAST           : ISimpleDSLAST;
    FTokenizer     : ISimpleDSLTokenizer;
    FLookaheadToken: TTokenKind;
    FLookaheadIdent: string;
  strict protected
    function  FetchToken(allowed: TTokenKinds; var ident: string; var token: TTokenKind;
      skipOver: TTokenKinds = []): boolean; overload;
    function  FetchToken(allowed: TTokenKinds; var ident: string): boolean; overload; inline;
    function  FetchToken(allowed: TTokenKinds): boolean; overload; inline;
    function  GetToken(var token: TTokenKind; var ident: string): boolean;
    function  IsFunction(const ident: string): boolean;
    function  IsNumber(const ident: string): boolean;
    function  IsVariable(const ident: string): boolean;
    function ParseBlock(var block: IASTBlock): boolean;
    function  ParseExpression(const expression: IASTExpression): boolean;
    function  ParseFunction: boolean;
    function  ParseIf(const statement: IASTIfStatement): boolean;
    function  ParseReturn(const statement: IASTReturnStatement): boolean;
    function ParseStatement(var statement: IASTStatement): boolean;
    function  ParseTerm(const term: IASTTerm): boolean;
    procedure PushBack(token: TTokenKind; const ident: string);
    property AST: ISimpleDSLAST read FAST;
  public
    function Parse(const code: string; const tokenizer: ISimpleDSLTokenizer;
      const ast: ISimpleDSLAST): boolean;
  end; { TSimpleDSLParser }

{ exports }

function CreateSimpleDSLParser: ISimpleDSLParser;
begin
  Result := TSimpleDSLParser.Create;
end; { CreateSimpleDSLParser }

{ TSimpleDSLParser }

function TSimpleDSLParser.FetchToken(allowed: TTokenKinds; var ident: string;
  var token: TTokenKind; skipOver: TTokenKinds): boolean;
var
  loc: TPoint;
begin
  Result := false;
  while GetToken(token, ident) do
    if token in allowed then
      Exit(true)
    else if (token = tkWhitespace) or (token in skipOver) then
      // do nothing
    else begin
      loc := FTokenizer.CurrentLocation;
      LastError := Format('Invalid syntax in line %d, character %d', [loc.X, loc.Y]);
      Exit;
    end;
end; { TSimpleDSLParser.FetchToken }

function TSimpleDSLParser.FetchToken(allowed: TTokenKinds; var ident: string): boolean;
var
  token: TTokenKind;
begin
  Result := FetchToken(allowed, ident, token);
end; { TSimpleDSLParser.FetchToken }

function TSimpleDSLParser.FetchToken(allowed: TTokenKinds): boolean;
var
  ident: string;
begin
  Result := FetchToken(allowed, ident);
end; { TSimpleDSLParser.FetchToken }

function TSimpleDSLParser.GetToken(var token: TTokenKind; var ident: string): boolean;
begin
  if FLookaheadIdent <> #0 then begin
    token := FLookaheadToken;
    ident := FLookaheadIdent;
    FLookaheadIdent := #0;
    Result := true;
  end
  else
    Result :=  FTokenizer.GetToken(token, ident);
end; { TSimpleDSLParser.GetToken }

function TSimpleDSLParser.IsFunction(const ident: string): boolean;
begin
  Result := false;
  // TODO 1 Implement: TSimpleDSLParser.IsFunction
end; { TSimpleDSLParser.IsFunction }

function TSimpleDSLParser.IsNumber(const ident: string): boolean;
begin
  Result := false;
  // TODO 1 Implement: TSimpleDSLParser.IsNumber
end; { TSimpleDSLParser.IsNumber }

function TSimpleDSLParser.IsVariable(const ident: string): boolean;
begin
  Result := false;
  // TODO 1 Implement: TSimpleDSLParser.IsVariable
end; { TSimpleDSLParser.IsVariable }

function TSimpleDSLParser.Parse(const code: string; const tokenizer: ISimpleDSLTokenizer;
  const ast: ISimpleDSLAST): boolean;
begin
  Result := false;
  FTokenizer := tokenizer;
  FAST := ast;
  FLookaheadIdent := #0;
  tokenizer.Initialize(code);
  while not tokenizer.IsAtEnd do
    if not ParseFunction then
      Exit;
  Result := true;
end; { TSimpleDSLParser.Parse }

function TSimpleDSLParser.ParseBlock(var block: IASTBlock): boolean;
var
  statement: IASTStatement;
begin
  Result := false;

  /// block = statement NL

  block := AST.CreateBlock;

  if not ParseStatement(statement) then
    Exit;

  block.Statement := statement;

  if not FetchToken([tkNewLine]) then
    Exit;

  Result := true;
end; { TSimpleDSLParser.ParseBlock }

function TSimpleDSLParser.ParseExpression(const expression: IASTExpression): boolean;
var
  ident: string;
  term : IASTTerm;
  token: TTokenKind;
begin
  Result := false;

  /// expression = term
  ///            | term operator term
  ///
  /// operator = "+" | "-" | "<"

  if not ParseTerm(term) then
    Exit;

  if not FetchToken([tkLessThan, tkPlus, tkMinus], ident, token) then begin
    PushBack(token, ident);
    // insert term into AST
    Result := true;
    Exit;
  end;

  if not ParseTerm(term) then
    Exit;

  // insert binary operation into AST
  Result := true;
end; { TSimpleDSLParser.ParseExpression }

function TSimpleDSLParser.ParseFunction: boolean;
var
  block   : IASTBlock;
  expected: TTokenKinds;
  func    : IASTFunction;
  funcName: string;
  ident   : string;
  token   : TTokenKind;
begin
  Result := false;

  /// function = identifier "(" [ identifier { "," identifier } ] ")" NL block

  // function name
  if not FetchToken([tkIdent], funcName, token, [tkNewLine]) then
    Exit;

  func := AST.CreateFunction;
  func.Name := funcName;

  // (
  if not FetchToken([tkLeftParen]) then
    Exit;

  // parameter list
  expected := [tkIdent, tkRightParen];
  repeat
    if not FetchToken(expected, ident, token) then
      Exit;
    if token = tkRightParen then
      break //repeat
    else if token = tkIdent then begin
      func.ParamNames.Add(ident);
      expected := expected - [tkIdent] + [tkComma];
    end
    else if token = tkComma then
      expected := expected + [tkIdent] - [tkComma]
    else begin
      LastError := 'Internal error in ParseFunction';
      Exit;
    end;
  until false;

  if not FetchToken([tkNewLine]) then
    Exit;

  Result := ParseBlock(block);

  if Result then begin
    func.Body := block;
    AST.Functions.Add(func);
  end;
end; { TSimpleDSLParser.ParseFunction }

function TSimpleDSLParser.ParseIf(const statement: IASTIfStatement): boolean;
var
  condition: IASTExpression;
  elseBlock: IASTBlock;
  ident    : string;
  loc      : TPoint;
  thenBlock: IASTBlock;
begin
  Result := false;

  /// if = "if" expression NL block "else" NL block
  /// ("if" was already parsed)

  if not ParseExpression(condition) then
    Exit;

  if not FetchToken([tkNewLine]) then
    Exit;

  if not ParseBlock(thenBlock) then
    Exit;

  if not FetchToken([tkIdent], ident) then
    Exit;

  if not SameText(ident, 'else') then begin
    loc := FTokenizer.CurrentLocation;
    LastError := Format('"else" expected in line %d, column %d', [loc.X, loc.Y]);
    Exit;
  end;

  if not FetchToken([tkNewLine]) then
    Exit;

  if not ParseBlock(elseBlock) then
    Exit;

  statement.Condition := condition;
  statement.ThenBlock := thenBlock;
  statement.ElseBlock := elseBlock;

  Result := true;
end; { TSimpleDSLParser.ParseIf }

function TSimpleDSLParser.ParseReturn(const statement: IASTReturnStatement): boolean;
var
  expression: IASTExpression;
begin
  /// return = "return" expression
  /// ("return" was already parsed)

  Result := ParseExpression(expression);

  if Result then
    statement.Expression := expression;
end; { TSimpleDSLParser.ParseReturn }

function TSimpleDSLParser.ParseStatement(var statement: IASTStatement): boolean;
var
  ident: string;
  loc  : TPoint;
begin
  Result := false;

  /// statement = if
  ///           | return

  if not FetchToken([tkIdent], ident) then
    Exit;

  if SameText(ident, 'if') then begin
    statement := AST.CreateStatement(stIf);
    Result := ParseIf(statement as IASTIfStatement);
  end
  else if SameText(ident, 'return') then begin
    statement := Ast.CreateStatement(stReturn);
    Result := ParseReturn(statement as IASTReturnStatement);
  end
  else begin
    loc := FTokenizer.CurrentLocation;
    LastError := Format('Invalid reserved word %s in line %d, column %d', [ident, loc.X, loc.Y]);
  end;
end; { TSimpleDSLParser.ParseStatement }

function TSimpleDSLParser.ParseTerm(const term: IASTTerm): boolean;
var
  ident: string;
  loc  : TPoint;
begin
  Result := false;

  /// term = numeric_constant
  ///      | function_call
  ///      | identifier
  ///
  /// function_call = identifier "(" [expression { "," expression } ] ")"

  if not FetchToken([tkIdent], ident) then
    Exit;

  // TODO 1 -oPrimoz Gabrijelcic : *** continue here ***

  if IsFunction(ident) then
    // parse function call
  else if IsNumber(ident) then
    // parse numeric constant
  else if IsVariable(ident) then
    // parse variable
  else begin
    loc := FTokenizer.CurrentLocation;
    LastError := Format('Unexpected token in line %d, column %d (not a number, variable, or function)', [loc.X, loc.Y]);
  end;
end; { TSimpleDSLParser.ParseTerm }

procedure TSimpleDSLParser.PushBack(token: TTokenKind; const ident: string);
begin
  Assert(ident = #0, 'TSimpleDSLParser: Lookahead buffer is not empty');
  FLookaheadToken := token;
  FLookaheadIdent := ident;
end; { TSimpleDSLParser.PushBack }

end.
