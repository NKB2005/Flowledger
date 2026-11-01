
// // main() {
// //   stdout.writeln('What is your name?');
// //   String? name = stdin.readLineSync();
// //   stdout.writeln('Hello, $name!');
// //   }

// // void main() {
// //   stdout.writeln('Enter the first number:');
// //   int x = int.parse(stdin.readLineSync()!);

// //   stdout.writeln('Enter the seconde number:');
// //   int y = int.parse(stdin.readLineSync()!);

// //   int sum = x + y;
// //   print('The sum of $x and $y is $sum');
// // }

// // Dynamic variable mean it can hold any type of value

// // main() {
// //   var one = int.parse('1');
// //   assert(one == 1);
// // }

// // void main() {
// //   for(int i = 0; i<=5; i++) {
// //     print(i);
// //   }
// // }

// // void main() {
// //   var numbers = [1, 2, 3 ,4, 5];

// //   for(var n in numbers) {
// //     print(n);
// //   }
// // }

// // void main() {
// //   for(int i = 1; i<=20; i++) {
// //     if(i % 2== 0) {
// //       print(i);
// //     }
// //   }
// // }

// // void main() {
// //   List<String> names = ["Niranjan", "Krishna"];
// //   print(names);
// // }

// // FUNCTIONS:
// // i)Basic function
// // void greet() {
// //   print("Hello!");
// // }

// // void main() {
// //   greet(); //calling the function;
// // }

// // ii)Function with parameters
// // void sayHellow(String name) {
// //   print("Hello, $name!");
// // }

// // void main() {
// //   sayHellow("Niranjan");
// // }

// // iii)Function with return type
// // int add(int a, int b) {
// //   return a + b;
// // }

// // void main() {
// //   int sum = add(5, 4);
// //   print("The sum is $sum");
// // }

// // iv)Arrow function;
// // int mulNum(int x, int y) => x * y;

// // void main() {
// //   int product = mulNum(4, 5);
// //   print("The product is $product");
// // }

// dynamic printNum(dynamic value) {
//   print(value);
//   return value;
// }

// // void main() {
// //   printNum(10);
// //   printNum("Niranjan");
// //   printNum(5.5);
// // }

// // Anonymous function;
// // void main() {
// //   var list = [1, 2, 3, 4, 5];

// //   list.forEach((num) {
// //     print(num);
// //   });
// // }

// void checkEvenOdd(int number) {
//   if(number % 2 == 0) {
//     print("$number is Even");
//   } else {
//     print("$number is Odd");
//   }
// }

// // void main() {
// //   checkEvenOdd(7);
// //   checkEvenOdd(10);
// // }

// void largestNum(int a, int b) {
//   if (a > b) {
//     print('$a is larger than $b');
//   } else if (a < b) {
//     print('$b is larger than $a');
//   } else {
//     print('Both numbers are equal');
//   }
// }

// // void main() {
// //   largestNum(5, 3);
// //   largestNum(0, 1);
// //   largestNum(4, 4);
// //   largestNum(-1, 3);
// // }

// // Named Parameters............
// void namedPara({required String name, int age = 18}) {
//   print("Name: $name, Age: $age");
// }

// // void main() {
// //   namedPara(name : "Niranjan" );
  
// // }

// void login({required String username, required String email, required String password}) {
//   print("Username: $username");
//   print("Email: $email");
//   print("Password: $password");
// }

// // void main() {
// //   login(username: "Niranjan", email:"krisnaniranjan773@gmail.com", password:"12345");
// // }

// // Optional parameters...........

// void greet(String name, [String? message]) {
//   print("Hello $name");

//   if(message !=Null) {
//     print(message);
//   }
// }

// // void main() {
// //   greet("Niranjan", "Welcome to dart programming");
// // }

// void newUser(String username, [String? password]) {
//   print("Username: $username");
//   print("Password: $password");
// }

// // void main() {
// //   newUser("Niranjan", "");
// // }

// // Classes in Dart; it is like a blueprint
// class student {
//   String name = "";
//   // you can write the string name; but you have to use the string?name:nullable type;
//   int age = 0;

//   void display() {
//     print("Name: $name");
//     print("Age:$age");
//   }
// }

// // void main() {
// //   student s = student();
// //   s.name = "Niranjan";
// //   s.age = 21;
// //   s.display();
// // }

// class Lapbrand {
//   String brandName = "";
//   String ram = "";
//   double price = 0.0;

//   void display() {
//     print("Brand Name: $brandName");
//     print("RAM: $ram");
//     print("price: $price");
//   }
// }
// // void main() {
// //   Lapbrand lp = Lapbrand();
// //   lp.brandName = "Lenovo";
// //   lp.ram = "8GB";
// //   lp.price = 55000.0;
// //   lp.display();
// // }

// class Mobile {
//   String brandName = "";
//   String model = "";

//   void makeCall() {
//     print("Person is making a call in $brandName $model");
//   }

//   void sendMessage() {
//     print("Person is sending a message in $brandName $model");
//   }
// }

// // void main() {
// //   Mobile mb = Mobile();
// //   mb.brandName = "Samsung";
// //   mb.model = "Galaxy S23";
// //   mb.makeCall();
// //   mb.sendMessage();
// // }



// // Constructor in Dart;
// class std {
//   String name;
//   int age;

//   std(this.name, this.age);

//   void display() {
//     print("Name: $name");
//     print("Age: $age");
//   }
// }

// // void main() {
// //   std su = std("Niranjan", 21);
// //   su.display();
// // }

// class book{
//   String title = "";
//   String author = "";
//   double price = 0.0;

//   book(this.title, this.author, this.price);

//   void display() {
//     print("Title: $title");
//     print("Author: $author");
//     print("Price: $price");
//   }
// }
// // void main() {
// //   book b = book("Atomic Habit","James Clear", 700.00);
// //   b.display();
// // }

// // Inheritance in Dart;
// // class animal {
// //   void eat() {
// //     print("Animal  is eating");
// //   }
// // }
// // class dog extends animal {
// //   void bark() {
// //     print("Dog is barking");
// //   }
// // }
// // void main() {
// //   dog d = dog();
// //   d.eat();
// //   d.bark();
// // }

// // Method overriding in Dart;
// class Animal {
//   void speak() {
//     print("Animal makes a sound");
//   }
// }

// class Dog extends Animal {
//   @override
//   void speak() {
//     print("Dog barks!");
//   }
// }

// // void main() {
// //   Dog myDog = Dog();
// //   Animal myAnimal = Animal();
// //   myDog.speak();      // Outputs: Dog barks!
// //   myAnimal.speak();   // Outputs: Animal makes a sound
// // }

// class Vehicle {
//   void start() {
//     print("Vehicle is starting");
//   }
// }

// class Car extends Vehicle {
//   @override
//   void start() {
//     print("Car is starting.....");
//   }
// }
// // void main() {
// //   Vehicle v = Vehicle();
// //   Car c = Car();
// //   v.start();
// //   c.start();
// // }

// // Super Class;
// class Person {
//   void laugh(){
//     print("Person laughs");
//   }
// }

// class Child extends Person {
//   @override
//   void laugh() {
//     super.laugh();
//     print("Child laughs");
//   }
// }
// // void main(){
// //   Person p = Person();
// //   p.laugh();
// //   Child c = Child();
// //   c.laugh();
// // }

// class Printer {
//   void printInfo() {
//     print("Printing information.....");
//   }
// }
// class Printing extends Printer {
//   @override
//   void printInfo(){
//     super.printInfo();
//     print("Printing Color info");
//   }
// }
// void main() {
//   Printer p = Printer();
//   p.printInfo();
//   Printing pr = Printing();
//   pr.printInfo();
// }