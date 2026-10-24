// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <algorithm>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace axon {
using Key = std::pair<std::string, std::string>; // app, notification identifier
struct Record { Key key; double timestamp = 0; };
struct Group { std::string app; size_t count = 0; double latest = 0; };
enum class Sort { Recent, Count, Identifier };

// UI-independent state. No message text, persistence, or background workers.
class NotificationIndex {
    std::map<Key, Record> records_;
    std::optional<std::string> selection_;
public:
    bool upsert(Record record) {
        if (record.key.first.empty() || record.key.second.empty()) return false;
        records_[record.key] = std::move(record);
        return true;
    }
    bool erase(const Key &key) {
        bool removed = records_.erase(key) != 0;
        normalizeSelection();
        return removed;
    }
    void reset() { records_.clear(); selection_.reset(); }
    void select(std::optional<std::string> app) {
        selection_ = std::move(app);
        normalizeSelection();
    }
    const std::optional<std::string> &selection() const { return selection_; }
    bool contains(const Key &key) const { return records_.count(key) != 0; }
    bool includes(const Key &key) const {
        return !selection_ || key.first == *selection_;
    }
    size_t size() const { return records_.size(); }
    std::set<Key> visibleKeys() const {
        std::set<Key> keys;
        for (const auto &item : records_) if (includes(item.first)) keys.insert(item.first);
        return keys;
    }
    std::vector<Group> groups(Sort sort = Sort::Recent) const {
        std::map<std::string, Group> grouped;
        for (const auto &item : records_) {
            auto &group = grouped[item.first.first];
            group.app = item.first.first;
            if (group.count == 0 || item.second.timestamp > group.latest)
                group.latest = item.second.timestamp;
            ++group.count;
        }
        std::vector<Group> result;
        for (const auto &item : grouped) result.push_back(item.second);
        std::sort(result.begin(), result.end(), [sort](const Group &a, const Group &b) {
            if (sort == Sort::Count && a.count != b.count) return a.count > b.count;
            if (sort != Sort::Identifier && a.latest != b.latest) return a.latest > b.latest;
            return a.app < b.app;
        });
        return result;
    }
private:
    void normalizeSelection() {
        if (!selection_) return;
        auto it = records_.lower_bound({*selection_, ""});
        if (it == records_.end() || it->first.first != *selection_) selection_.reset();
    }
};
} // namespace axon
