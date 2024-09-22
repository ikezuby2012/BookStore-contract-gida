// BOOKSTORE CONTRACT WILL HAVE THE FOLLOW
// Create an author
// buy a book
// author can create a book
// author can edit a book
// author can delete a book

//*******************************
// there are two types of actors i.e user, author and admin,
// a user can buy and view a book
// an author can create, view, edit and delete a book
//******************************

#[derive(Copy, Drop, Serde, starknet::Store)]
struct User {
    name: felt252,
    isAuthor: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Book {
    name: felt252,
    author_id: User,
    quantity: u8,
    price: felt252,
    is_available: bool,
    is_soft_deleted: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct PurchasedBooks {
    user_id: User,
    book_id: Book,
    quantity: u8,
}

#[starknet::interface]
pub trait IBookStore<TContractState> {
    fn create_user(ref self: TContractState, user_id: felt252, name: felt252) -> User;
    fn create_author(ref self: TContractState, user_id: felt252) -> User;
    fn create_book(
        ref self: TContractState, user_id: felt252, name: felt252, quantity: u8, price: felt252
    ) -> Book;
    fn update_book(
        ref self: TContractState,
        user_id: felt252,
        book_id: felt252,
        new_quantity: u8,
        price: felt252,
        is_available: bool
    );
    fn delete_book(ref self: TContractState, user_id: felt252, book_id: felt252);
    fn buy_book(
        ref self: TContractState,
        user_id: felt252,
        book_id: felt252,
        quantity: u8,
        price: felt252
    );
    fn get_book(self: @TContractState, book_id: felt252) -> Book;
}

#[starknet::contract]
pub mod BookStore {
    use super::{User, Book, PurchasedBooks, IBookStore};
    use core::starknet::{
        get_caller_address, ContractAddress,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess}
    };


    #[storage]
    struct Storage {
        users: Map<felt252, User>,
        books: Map<felt252, Book>,
        purchased_books: Map<felt252, PurchasedBooks>,
        admin_address: ContractAddress,
        book_count: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        self.admin_address.write(admin_address);
        self.book_count.write(0);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserAdded: UserAdded,
        BookAdded: BookAdded,
        UserUpdated: UserUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct UserAdded {
        name: felt252,
        user_id: felt252,
        isAuthor: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct UserUpdated {
        name: felt252,
        user_id: felt252,
        isAuthor: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct BookAdded {
        name: felt252,
        AuthorId: User,
        quantity: u8,
        price: felt252,
        is_available: bool,
        is_soft_deleted: bool,
    }


    #[abi(embed_v0)]
    impl BookStoreImpl of IBookStore<ContractState> {
        fn create_user(ref self: ContractState, user_id: felt252, name: felt252) -> User {
            // let caller = get_caller_address();
            // assert(caller.is_zero(), 'Error: Invalid caller address');
            let user = User { name: name, isAuthor: false };
            self.users.write(user_id, user);

            self.emit(UserAdded { name, user_id, isAuthor: false });
            user
        }

        fn create_author(ref self: ContractState, user_id: felt252) -> User {
            let admin_address = self.admin_address.read();
            assert(get_caller_address() == admin_address, 'Cannot update user role');
            let mut user = self.users.read(user_id);
            assert(user.name != 0, 'User does not exist');

            user.isAuthor = true;
            self.users.write(user_id, user);

            self.emit(UserUpdated { name: user.name, user_id, isAuthor: true });
            user
        }

        fn create_book(
            ref self: ContractState, user_id: felt252, name: felt252, quantity: u8, price: felt252
        ) -> Book {
            // let caller = get_caller_address();
            // assert(!caller.is_zero(), 'Error: Invalid caller address');

            let user = self.users.read(user_id);
            assert(user.name != 0, 'User does not exist');
            assert(user.isAuthor, 'Only authors can create books');
            let book_id = self.book_count.read() + 1;
            let book = Book {
                name, author_id: user, quantity, price, is_available: true, is_soft_deleted: false
            };
            self.books.write(book_id, book);
            self.book_count.write(book_id);

            self.emit(BookAdded { 
                name, 
                AuthorId: user, 
                quantity, 
                price, 
                is_available: true, 
                is_soft_deleted: false 
            });

            book
        }

        fn update_book(
            ref self: ContractState,
            user_id: felt252,
            book_id: felt252,
            new_quantity: u8,
            price: felt252,
            is_available: bool
        ) {
            // let caller = get_caller_address();
            // assert(caller.is_zero(), 'Error: Invalid caller address');

            let user = self.users.read(user_id);
            assert(user.isAuthor, 'Only authors can update books');

            let mut book = self.books.read(book_id);
            assert(book.author_id.name == user.name, 'Only the book author can edit');

            book.quantity = new_quantity;
            book.price = price;
            book.is_available = is_available;
            self.books.write(book_id, book);
        }
        fn delete_book(ref self: ContractState, user_id: felt252, book_id: felt252) {
            // let caller = get_caller_address();
            // assert(caller.is_zero(), 'Error: Invalid caller address');

            let user = self.users.read(user_id);
            assert(user.name != 0, 'User does not exist');
            assert(user.isAuthor, 'Only authors can delete books');

            let mut book = self.books.read(book_id);
            assert(book.name != 0, 'Book does not exist');
            assert(book.author_id.name == user.name, 'Only the book author can delete');

            book.quantity = 0;
            book.is_available = false;
            book.is_soft_deleted = true;
            self.books.write(book_id, book);
        }

        fn buy_book(
            ref self: ContractState,
            user_id: felt252,
            book_id: felt252,
            quantity: u8,
            price: felt252
        ) {
            let user = self.users.read(user_id);
            let mut book = self.books.read(book_id);

            assert(book.name != 0, 'Book does not exist');

            assert(book.is_available, 'Book is not available');
            assert(!book.is_soft_deleted, 'Book no longer exists');
            assert(book.price == price, 'Price does not match');
            assert(book.quantity >= quantity, 'Not enough books available');

            book.quantity -= quantity;
            if book.quantity == 0 {
                book.is_available = false;
            }
            let purchased_book = PurchasedBooks {
                user_id: user, book_id: book, quantity
            };
            self.books.write(book_id, book);
            self.purchased_books.write(user_id, purchased_book);
        }

        fn get_book(self: @ContractState, book_id: felt252) -> Book {
            self.books.read(book_id)
        }
    }
}
