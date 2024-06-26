module co_invest_club::co_invest_club {
    // Necessary imports
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    
    use std::string::{String};
    
    // Gender enum
    enum Gender {
        Male,
        Female,
    }

    // Status enum
    enum InvestmentStatus {
        Pending,
        Paid,
        Overdue,
    }
    
    // Errors 
    const ERROR_INVALID_GENDER: u64 = 0;
    const ERROR_INVALID_ACCESS: u64 = 1;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 2;
    const ERROR_INVALID_TIME: u64 = 3;
    const ERROR_INVESTMENT_ALREADY_PAID: u64 = 4;
    
    // Struct Definitions
    
    // Club struct
    struct Club has key, store {
        id: UID,
        name: String,
        club_type: String,
        rules: vector<u8>,
        description: vector<u8>,
        members: Table<address, Member>,
        investments: Table<address, Investment>,
        balance: Balance<SUI>,
        founding_date: u64,
        status: vector<u8>,
    }
    
    // struct that represent Club Capability
    struct ClubCap has key {
        id: UID,
        club_id: ID,
    }

    // Member Struct
    struct Member has key, store {
        id: UID,
        club_id: ID,
        name: String,
        gender: Gender,
        contact_info: String,
        number_of_shares: u64,
        pay: bool,
        date_joined: u64
    }

    // Investment Struct
    struct Investment has copy, store, drop {
        member_id: ID,
        amount_payable: u64,
        payment_date: u64,
        status: InvestmentStatus,
    }

    // Create a new Club
    public fun create_club(
        name: String,
        club_type: String,
        description: vector<u8>,
        rules: vector<u8>,
        clock: &Clock,
        open: vector<u8>,
        ctx: &mut TxContext
    ): (Club, ClubCap) {
        // Add access control mechanism here
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let club = Club {
            id: id_,
            name,
            club_type,
            description,
            rules,
            status: open,
            founding_date: clock::timestamp_ms(clock),
            members: table::new(ctx),
            investments: table::new(ctx),
            balance: balance::zero()
        };

        let cap = ClubCap {
            id: object::new(ctx),
            club_id: inner_,
        };
        (club, cap)
    }
    
    // Add a member to the club
    public fun add_member(
        club_id: ID,
        name: String,
        gender: Gender,
        contact_info: String,
        number_of_shares: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Member {
        let member = Member {
            id: object::new(ctx),
            club_id,
            name,
            gender,
            contact_info,
            number_of_shares,
            date_joined: clock::timestamp_ms(clock),
            pay: false
        };
        // Add input validation here
        member
    }
    
    // Generate investment amount for a member
    public fun generate_investment_amount(
        cap: &ClubCap,
        club: &mut Club,
        member: &Member,
        member_id: ID,
        amount_payable: u64,
        status: InvestmentStatus,
        date: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(cap.club_id == object::id(club), ERROR_INVALID_ACCESS);
        
        // Accessing number of shares from the Member struct
        let shares = member.number_of_shares;
        
        // Calculate the total amount payable based on the number of shares
        let total_amount_payable = amount_payable * shares;
        
        let investment = Investment {
            member_id,
            amount_payable: total_amount_payable, // Use the adjusted total amount
            status,
            payment_date: clock::timestamp_ms(clock) + date,
        };
        table::add(&mut club.investments, sender(ctx), investment);
    }
    
    // Function for member to pay investment
    public fun pay_investment(
        club: &mut Club,
        investment: &mut Investment,
        member: &mut Member,
        coin: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure the investment is not already paid or canceled
        assert!(
            investment.status == InvestmentStatus::Pending
                || investment.status == InvestmentStatus::Overdue,
            ERROR_INVESTMENT_ALREADY_PAID
        );
        
        assert!(investment.payment_date < clock::timestamp_ms(clock), ERROR_INVALID_TIME);
        assert!(coin::value(&coin) == investment.amount_payable, ERROR_INSUFFICIENT_FUNDS);
        
        let investment = table::remove(&mut club.investments, sender(ctx));
        
        // Add the coin to the club balance
        let balance_ = coin::into_balance(coin);
        balance::join(&mut club.balance, balance_);
        // Investment Status
        member.pay = true;
        investment.status = InvestmentStatus::Paid;
    }
    
    // Function to withdraw funds from the club
    public fun withdraw_funds(
        cap: &ClubCap,
        club: &mut Club,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(cap.club_id == object::id(club), ERROR_INVALID_ACCESS);
        // Add authorization check here
        let balance_ = balance::withdraw_all(&mut club.balance);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }
    
    // Function to get the total balance of the club
    public fun get_balance(club: &Club): u64 {
        balance::value(&club.balance)
    }
    
    // Function to check the payment and investment status of a member
    public fun check_member_and_investment_status(
        member: &Member,
        investment: &Investment
    ): (bool, InvestmentStatus) {
        (member.pay, investment.status)
    }
}
