# infinite_list_view
Allows you to create paginated infinite lists with smooth transitions.

## Features
- Maintains the view when a new page is added. Normally, the viewable content jumps when new items are added to a list. 
- Supports inserting items on top of the list. Auto scrolls to view those new items if the user is viewing the bottom of the list.
- You can also keep track of visible items
- 
## Usage
Use it like a normal `ListView` in your widget tree.

Don't forget to define a persistent GlobalKey as the `_listKey`

Using the `_listKey`, you can add pages and insert items to the list.

```dart
  static const _pageSize = 8;

  final _listKey =
      GlobalKey<InfiniteListViewState<String, ItemModel, String>>();

  Future<void> _requestPage(String pageKey) async {
    await Future.delayed(const Duration(seconds: 3));

    final items = <ItemModel>[];
    for (var i = 0; i < _pageSize; i++) {
      items.add(ItemModel(
          '${_listKey.currentState!.items.length + i}, ${Object().hashCode.toString()}'));
    }

    _listKey.currentState!.addPage(
      pageItems: items,
      pageKey: items.last.id,
      isLastPage: _listKey.currentState!.items.length > 100,
    );
  }

  void _addNewMessage() {
    _listKey.currentState!.addNewItems(
      items: [ItemModel(Object().hashCode.toString())],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewMessage,
        child: const Icon(Icons.add),
      ),
      body: InfiniteListView<String, ItemModel, String>(
        key: _listKey,
        initialPageKey: '',
        requestPage: _requestPage,
        itemBuilder: (context, index) => ItemTile(
          model: _listKey.currentState!.items[index],
        ),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        shouldWatchVisiblity: (index) =>
            (_listKey.currentState!.items.length - index) % 5 == 0,
        onVisibilityChange: (visibleItems) {
          debugPrint('InfiniteListView. onVisibilityChange: ${visibleItems.map((e) => e.id)}');
        },
        padding: const EdgeInsets.all(16),
        androidLoaderColor: Colors.pink,
      ),
    );
  }
```