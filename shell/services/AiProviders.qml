pragma Singleton
import QtQuick
import Quickshell

// Signatures only. Bodies come in phase 7.
Singleton {
    property var providers           // list of AiProvider (built-in plus user-added)
    // TODO(phase 7): FileView + JsonAdapter for config/ai-providers.json and ~/.config/aptus/ai-providers.json.

    // Built-in providers plus the user's own.
    function load(): var {
        throw new Error("not implemented")
    }

    function add(provider: var): void {
        if (!provider || !provider.id) throw new Error("invariant: AiProviders.add: provider needs an id")
        if (provider.builtIn) throw new Error("invariant: AiProviders.add: built-in providers are not added by the user")
        if (!provider.quickArgs || provider.quickArgs.filter(a => a === "{prompt}").length !== 1) throw new Error("invariant: AiProviders.add: quickArgs must contain {prompt} exactly once")
        if ((providers || []).some(p => p.id === provider.id)) throw new Error("invariant: AiProviders.add: duplicate provider id")
        throw new Error("not implemented")
    }

    // Only user-added providers.
    function remove(providerId: string): void {
        if (!providerId) throw new Error("invariant: AiProviders.remove: empty provider id")
        if ((providers || []).some(p => p.id === providerId && p.builtIn)) throw new Error("invariant: AiProviders.remove: built-in providers cannot be removed")
        throw new Error("not implemented")
    }

    function setEnabled(providerId: string, on: bool): void {
        if (!providerId) throw new Error("invariant: AiProviders.setEnabled: empty provider id")
        if (!on && (providers || []).filter(p => p.enabled && p.id !== providerId).length === 0) throw new Error("invariant: AiProviders.setEnabled: the last enabled provider cannot be disabled")
        throw new Error("not implemented")
    }

    function saveUser(): void {
        throw new Error("not implemented")
    }
}
