// ignore_for_file: unnecessary_this
library functional_listener;

import 'package:flutter/foundation.dart';
import 'package:functional_listener/src/functional_value_notifiers.dart';

/// extension functions on `ValueListenable` that allows you to work with them almost
/// as if it was a synchronous stream. Each extension function returns a new
/// `ValueNotifier` that updates its value when the value of `this` changes
/// You can chain these functions to build complex processing
/// pipelines from a simple `ValueListenable`
/// In the examples we use [listen] to react on value changes. Instead of applying [listen] you
/// could also pass the end of the function chain to a `ValueListenableBuilder`
extension FunctionaListener<T> on ValueListenable<T> {
  ///
  /// let you work with a `ValueListenable` as it should be by installing a
  /// [handler] function that is called on any value change of `this` and gets
  /// the new value passed as an argument.
  /// It returns a subscription object that lets you stopp the [handler] from
  /// being called by calling [cancel()] on the subscription.
  /// The [handler] get the subscription object passed on every call so that it
  /// is possible to uninstall the [handler] from the [handler] itself.
  ///
  /// example:
  /// ```
  ///
  /// final listenable = ValueNotifier<int>(0);
  /// final subscription = listenable.listen((x, _) => print(x));
  ///
  /// final subscription = listenable.listen((x, subscription) {
  ///   print(x);
  ///   if (x == 42){
  ///      subscription.cancel();
  ///   }
  /// }
  ///
  ListenableSubscription listen(
      void Function(T, ListenableSubscription) handler) {
    final subscription = ListenableSubscription(this);
    subscription.handler = () => handler(this.value, subscription);
    this.addListener(subscription.handler);
    return subscription;
  }

  ///
  /// converts a ValueListenable to another type [T] by returning a new connected
  /// `ValueListenable<T>`
  /// on each value change of `this` the conversion funcion
  /// [convert] is called to do the type conversion
  ///
  /// example (lets pretend that print wouldn't automatically call toString):
  /// ```
  /// final sourceListenable = ValueNotifier<int>(0);
  /// final subscription = sourceListenable.map<String>( (x)
  ///    => x.toString()).listen( (s,_) => print(x) );
  ///```
  ValueListenable<TResult> map<TResult>(TResult Function(T) convert) {
    return MapValueNotifier<T, TResult>(
      convert(this.value),
      this,
      convert,
    );
  }

  ///
  /// [where] allows you to set a filter on a `ValueListenable` so that an installed
  /// handler function is only called if the passed
  /// [selector] function returns true. Because the selector function is called on
  /// every new value you can change the filter during runtime.
  ///
  /// example: lets only print even values
  /// ```
  /// final sourceListenable = ValueNotifier<int>(0);
  /// final subscription = sourceListenable.where( (x)=>x.isEven )
  ///    .listen( (s,_) => print(x) );
  ///```
  ValueListenable<T> where(bool Function(T) selector) {
    return WhereValueNotifier(this.value, this, selector);
  }

  ///
  /// If you get too much value changes during a short time period and you don't
  /// want or can handle them all [debounce] can help you.
  /// If you add a [debounce] to your listenable processing pipeline the returned
  /// `ValueListenable` will not emit an updated value before at least
  /// [timpeout] time has passed since the less value change. All value changes
  /// in-between will be discarded.
  ///
  /// example:
  /// ```
  /// final listenable = ValueNotifier<int>(0);
  ///
  /// listenable
  ///     .debounce(const Duration(milliseconds: 500))
  ///     .listen((x, _) => print(x));
  ///
  /// listenable.value = 42;
  /// await Future.delayed(const Duration(milliseconds: 100));
  /// listenable.value = 43;
  /// await Future.delayed(const Duration(milliseconds: 100));
  /// listenable.value = 44;
  /// await Future.delayed(const Duration(milliseconds: 350));
  /// listenable.value = 45;
  /// await Future.delayed(const Duration(milliseconds: 550));
  /// listenable.value = 46;
  ///
  /// ```
  ///  will print out 42,45,46
  ///
  ValueListenable<T> debounce(Duration timeOut) {
    return DebouncedValueNotifier(this.value, this, timeOut);
  }

  ///
  /// Imagine having two `ValueNotifier` in you model and you want to update
  /// a certain region of the screen with their values every time one of them
  /// get updated.
  /// [combineLatest] combines two `ValueListenable` in that way that it returns
  /// a new `ValueNotifier` that changes its value of [TOut] whenever one of the
  /// input listenables [this] or [combineWith] updates its value. This new value
  /// is built by the [combiner] function that is called on any value change of
  /// the input listenables.
  ///
  /// example:
  /// ```
  ///    class StringIntWrapper {
  ///      final String s;
  ///      final int i;
  ///
  ///      StringIntWrapper(this.s, this.i);
  ///
  ///      @override
  ///      String toString() {
  ///        return '$s:$i';
  ///      }
  ///    }
  ///
  ///    final listenable1 = ValueNotifier<int>(0);
  ///    final listenable2 = ValueNotifier<String>('Start');
  ///
  ///    final destValues = <StringIntWrapper>[];
  ///    final subscription = listenable1
  ///        .combineLatest<String, StringIntWrapper>(
  ///            listenable2, (i, s) => StringIntWrapper(s, i))
  ///        .listen((x, _) {
  ///      destValues.add(x);
  ///    });
  ///
  ///    listenable1.value = 42;
  ///    listenable1.value = 43;
  ///    listenable2.value = 'First';
  ///    listenable1.value = 45;
  ///
  ///    expect(destValues[0].toString(), 'Start:42');
  ///    expect(destValues[1].toString(), 'Start:43');
  ///    expect(destValues[2].toString(), 'First:43');
  ///    expect(destValues[3].toString(), 'First:45');
  ///  ```
  ///
  ValueListenable<TOut> combineLatest<TIn2, TOut>(
      ValueListenable<TIn2> combineWith,
      CombiningFunction2<T, TIn2, TOut> combiner) {
    return CombiningValueNotifier<T, TIn2, TOut>(
      combiner(this.value, combineWith.value),
      this,
      combineWith,
      combiner,
    );
  }
}

/// Object that is returned by [listen] that allows you to stop the calling of the
/// handler that you passed to it.
class ListenableSubscription {
  final ValueListenable endOfPipe;
  VoidCallback handler;
  bool canceled = false;

  ListenableSubscription(this.endOfPipe);

  /// Removes the handler that you installed with [listen]
  /// It's save to call cancel on an already canceled subscription
  void cancel() {
    assert(handler != null);
    if (!canceled) {
      endOfPipe.removeListener(handler);
      canceled = true;
    }
  }
}
