/*
 *Copyright (C) 2018 Laurent Tréguier
 *
 *This file is part of DLS.
 *
 *DLS is free software: you can redistribute it and/or modify
 *it under the terms of the GNU General Public License as published by
 *the Free Software Foundation, either version 3 of the License, or
 *(at your option) any later version.
 *
 *DLS is distributed in the hope that it will be useful,
 *but WITHOUT ANY WARRANTY; without even the implied warranty of
 *MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *GNU General Public License for more details.
 *
 *You should have received a copy of the GNU General Public License
 *along with DLS.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

module dls.tools.command_tool;

import dls.tools.tool : Tool;

enum Commands : string
{
    workspaceEdit = "workspaceEdit",
    codeAction_analysis_disableCheck = "codeAction.analysis.disableCheck"
}

class CommandTool : Tool
{
    import std.json : JSONValue;

    private static CommandTool _instance;

    static void initialize()
    {
        _instance = new CommandTool();
    }

    static void shutdown()
    {
        destroy(_instance);
    }

    @property static CommandTool instance()
    {
        return _instance;
    }

    @property string[] commands()
    {
        string[] result;

        foreach (member; __traits(allMembers, Commands))
        {
            result ~= mixin("Commands." ~ member);
        }

        return result;
    }

    JSONValue executeCommand(in string commandName, in JSONValue[] arguments)
    {
        import dls.protocol.definitions : WorkspaceEdit;
        import dls.protocol.interfaces : ApplyWorkspaceEditParams;
        import dls.protocol.jsonrpc : InvalidParamsException, send;
        import dls.protocol.messages.methods : Workspace;
        import dls.tools.analysis_tool : AnalysisTool;
        import dls.util.json : convertFromJSON;
        import dls.util.logger : logger;
        import dls.util.uri : Uri;
        import std.json : JSONException;
        import std.format : format;

        logger.infof("Executing command %s with arguments %s", commandName, arguments);

        try
        {
            final switch (convertFromJSON!Commands(JSONValue(commandName)))
            {
            case Commands.workspaceEdit:
                send(Workspace.applyEdit,
                        new ApplyWorkspaceEditParams(convertFromJSON!WorkspaceEdit(arguments[0])));
                break;

            case Commands.codeAction_analysis_disableCheck:
                AnalysisTool.instance.disableCheck(new Uri(convertFromJSON!string(arguments[0])),
                        new Uri(convertFromJSON!string(arguments[1])));
                break;
            }
        }
        catch (JSONException e)
        {
            throw new InvalidParamsException(format!"unknown command: %s"(commandName));
        }

        return JSONValue(null);
    }
}
