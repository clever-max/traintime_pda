// Copyright 2026 BenderBlog Rodriguez and Contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:watermeter/generated/translations.g.dart';
import 'package:watermeter/page/public_widget/context_extension.dart';

import '../models/topic.dart';
import '../controller/ruisi_controller.dart';
import '../widgets/topic_list_item.dart';
import 'topic_detail_page.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ruisiService = GetIt.instance<RuisiService>();
  String search = '';
  bool _hasSearched = false;
  List<String> _searchHistory = [];
  late final _textEditingController = TextEditingController.fromValue(
    TextEditingValue(text: search),
  );
  late final _pagingController = PagingController<int, Topic>(
    getNextPageKey: (state) =>
        state.lastPageIsEmpty ? null : state.nextIntPageKey,
    fetchPage: (pageKey) => _ruisiService.search(search, pageKey),
  );

  @override
  void initState() {
    super.initState();
    _searchHistory = _ruisiService.settings.searchHistory;
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  void _submitSearch(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) {
      if (_hasSearched) setState(() => _hasSearched = false);
      return;
    }

    search = keyword;
    if (_textEditingController.text != keyword) {
      _textEditingController.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    setState(() => _hasSearched = true);
    _pagingController.refresh();
    unawaited(
      _ruisiService.settings
          .addSearchHistory(keyword)
          .then((history) {
            if (mounted) setState(() => _searchHistory = history);
          })
          .catchError((_) {}),
    );
  }

  Widget _buildSearchHistory(BuildContext context) {
    if (_searchHistory.isEmpty) {
      return Center(child: Text(context.t.ruisi.search.inputHint));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _searchHistory
          .map(
            (keyword) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(keyword),
              onTap: () => _submitSearch(keyword),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextFormField(
          controller: _textEditingController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.t.ruisi.search.hint,
            border: InputBorder.none,
          ),
          onChanged: (value) {
            search = value;
            if (value.trim().isEmpty && _hasSearched) {
              setState(() => _hasSearched = false);
            }
          },
          onFieldSubmitted: _submitSearch,
        ),
      ),
      body: _hasSearched
          ? PagingListener(
              controller: _pagingController,
              builder: (context, state, fetchNextPage) => LayoutBuilder(
                builder: (context, constraints) =>
                    PagedListView<int, Topic>.separated(
                      state: state,
                      fetchNextPage: fetchNextPage,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      builderDelegate: PagedChildBuilderDelegate(
                        itemBuilder: (context, item, index) => TopicListItem(
                          topic: item,
                          onTap: () =>
                              context.push(TopicDetailPage(tid: item.tid)),
                        ),
                      ),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                    ),
              ),
            )
          : _buildSearchHistory(context),
    );
  }
}
