module dls.protocol.messages.text_document;

import dls.protocol.interfaces;
import dls.tools.formatter;
import dls.util.document;
import dls.util.signal;
import std.concurrency;

void didOpen(DidOpenTextDocumentParams params)
{
    if (params.textDocument.languageId == "d")
    {
        Document.open(params.textDocument);
    }
}

void didChange(DidChangeTextDocumentParams params)
{
    receiveOnly!(Signal.MessageAtFront)();
    Document.change(params.textDocument, params.contentChanges);
}

void willSave(WillSaveTextDocumentParams params)
{
}

auto willSaveWaitUntil(WillSaveTextDocumentParams params)
{
    TextEdit[] result;
    return result;
}

void didSave(DidSaveTextDocumentParams params)
{
}

void didClose(DidCloseTextDocumentParams params)
{
    Document.close(params.textDocument);
}

auto completion(TextDocumentPositionParams params)
{
    CompletionItem[] result;
    return result;
}

@("completionItem", "resolve")
auto completionItem_resolve(CompletionItem item)
{
    return item;
}

auto hover(TextDocumentPositionParams params)
{
    auto result = new Hover();
    return result;
}

auto signatureHelp(TextDocumentPositionParams params)
{
    auto result = new SignatureHelp();
    return result;
}

auto references(ReferenceParams params)
{
    Location[] result;
    return result;
}

auto documentHighlight(TextDocumentPositionParams params)
{
    DocumentHighlight[] result;
    return result;
}

auto documentSymbol(DocumentSymbolParams params)
{
    SymbolInformation[] result;
    return result;
}

auto formatting(DocumentFormattingParams params)
{
    receiveOnly!(Signal.MessageAtFront)();
    auto formatResult = Formatter.formatFile(params.textDocument.uri, params.options);
    TextEdit[] result;

    result ~= new TextEdit();
    result[0].newText = formatResult[0];
    result[0].range = formatResult[1];

    return result;
}

auto rangeFormatting(DocumentRangeFormattingParams params)
{
    TextEdit[] result;
    return result;
}

auto onTypeFormatting(DocumentOnTypeFormattingParams params)
{
    TextEdit[] result;
    return result;
}

auto definition(TextDocumentPositionParams params)
{
    auto result = new Location();
    return result.nullable;
}

auto codeAction(CodeActionParams params)
{
    Command[] result;
    return result;
}

auto codeLens(CodeLensParams params)
{
    CodeLens[] result;
    return result;
}

@("codeLens", "resolve")
auto codeLens_resolve(CodeLens codeLens)
{
    return codeLens;
}

auto documentLink(DocumentLinkParams params)
{
    DocumentLink[] result;
    return result;
}

@("documentLink", "resolve")
auto documentLink_resolve(DocumentLink link)
{
    return link;
}

auto rename(RenameParams params)
{
    WorkspaceEdit[] result;
    return result;
}