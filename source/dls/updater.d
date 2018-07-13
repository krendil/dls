module dls.updater;

import dls.bootstrap : repoBase;
import dls.protocol.interfaces : InitializeParams;
import std.file : FileException;
import std.format : format;
import std.json : parseJSON;

private enum descriptionJson = import("description.json");
private immutable changelogUrl = format!"https://github.com/%s/dls/blob/master/CHANGELOG.md"(
        repoBase);

void cleanup()
{
    import dls.bootstrap : dubBinDir;
    import std.file : SpanMode, dirEntries, remove, rmdirRecurse;
    import std.path : baseName;
    import std.regex : matchFirst;

    bool[string] entriesToRemove;

    foreach (entry; dirEntries(dubBinDir, SpanMode.shallow))
    {
        const match = entry.name.baseName.matchFirst(`dls-v([\d.]+)`);

        if (match)
        {
            if (match[1] < currentVersion)
            {
                foreach (subEntry; dirEntries(entry.name, SpanMode.shallow))
                {
                    if (subEntry.baseName !in entriesToRemove)
                    {
                        entriesToRemove[subEntry.name.baseName] = true;
                    }
                }

                try
                {
                    rmdirRecurse(entry.name);
                }
                catch (FileException e)
                {
                }
            }
            else
            {
                foreach (subEntry; dirEntries(entry.name, SpanMode.shallow))
                {
                    entriesToRemove[subEntry.name.baseName] = false;
                }
            }
        }
    }

    foreach (entry; dirEntries(dubBinDir, SpanMode.shallow))
    {
        if (entry.name.baseName in entriesToRemove && entriesToRemove[entry.name.baseName])
        {
            try
            {
                remove(entry.name);
            }
            catch (FileException e)
            {
            }
        }
    }
}

void update()
{
    import core.time : hours;
    import dls.bootstrap : UpgradeFailedException, apiEndpoint, buildDls,
        canDownloadDls, downloadDls, linkDls;
    static import dls.protocol.jsonrpc;
    import dls.protocol.messages.methods : Dls;
    import dls.protocol.messages.window : Util;
    import dls.util.logger : logger;
    import dls.util.path : normalized;
    import dub.dependency : Dependency;
    import dub.dub : Dub, FetchOptions;
    import dub.semver : compareVersions;
    import std.algorithm : stripLeft;
    import std.concurrency : ownerTid, receiveOnly, register, send, thisTid;
    import std.datetime : Clock, SysTime;
    import std.net.curl : get;

    const latestRelease = parseJSON(get(format!apiEndpoint("releases/latest")));
    const latestVersion = latestRelease["tag_name"].str.stripLeft('v');
    const releaseDate = SysTime.fromISOExtString(latestRelease["published_at"].str);

    if (latestVersion.length == 0 || compareVersions(currentVersion,
            latestVersion) >= 0 || (Clock.currTime.toUTC() - releaseDate < 1.hours))
    {
        return;
    }

    auto id = Util.sendMessageRequest(Util.ShowMessageRequestType.upgradeDls,
            [latestVersion, currentVersion]);
    const threadName = "updater";
    register(threadName, thisTid());
    send(ownerTid(), Util.ThreadMessageData(id,
            Util.ShowMessageRequestType.upgradeDls, threadName));

    const shouldUpgrade = receiveOnly!bool();

    if (!shouldUpgrade)
    {
        return;
    }

    dls.protocol.jsonrpc.send(Dls.upgradeDls_start);

    scope (exit)
    {
        dls.protocol.jsonrpc.send(Dls.upgradeDls_stop);
    }

    bool success;

    if (canDownloadDls)
    {
        try
        {
            enum totalSizeCallback = (size_t size) {
                dls.protocol.jsonrpc.send(Dls.upgradeDls_totalSize, size);
            };
            enum chunkSizeCallback = (size_t size) {
                dls.protocol.jsonrpc.send(Dls.upgradeDls_currentSize, size);
            };
            enum extractCallback = () {
                dls.protocol.jsonrpc.send(Dls.upgradeDls_extract);
            };

            downloadDls(totalSizeCallback, chunkSizeCallback, extractCallback);
            success = true;
        }
        catch (Exception e)
        {
            logger.warningf("Could not download DLS: %s", e.message);
        }
    }

    if (!success)
    {
        auto dub = new Dub();
        FetchOptions fetchOpts;
        fetchOpts |= FetchOptions.forceBranchUpgrade;
        const pack = dub.fetch("dls", Dependency(">=0.0.0"),
                dub.defaultPlacementLocation, fetchOpts);

        int i;
        const additionalArgs = [[], ["--force"]];

        do
        {
            try
            {
                buildDls(pack.path.toString().normalized, additionalArgs[i]);
                success = true;
            }
            catch (UpgradeFailedException e)
            {
                ++i;
            }
        }
        while (i < additionalArgs.length && !success);

        if (!success)
        {
            Util.sendMessage(Util.ShowMessageType.dlsBuildError);
            return;
        }
    }

    try
    {
        linkDls();
        id = Util.sendMessageRequest(Util.ShowMessageRequestType.showChangelog, [latestVersion]);
        send(ownerTid(), Util.ThreadMessageData(id,
                Util.ShowMessageRequestType.showChangelog, changelogUrl));
    }
    catch (FileException e)
    {
        Util.sendMessage(Util.ShowMessageType.dlsLinkError);
    }
}

@property private string currentVersion()
{
    import std.algorithm : find;

    const desc = parseJSON(descriptionJson);
    return desc["packages"].array.find!(p => p["name"] == desc["rootPackage"])[0]["version"].str;
}
