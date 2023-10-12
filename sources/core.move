module sui_place::core{

    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::clock::Clock;

    use sui_place::canvas::{Self, CanvasStorage};

    struct Admin has key {
        id: UID,

    }

    struct CoreStorage has key {
        id: UID,
        fee_collector: address,
        fee: Balance<SUI>,
        pixel_cost: u64,
    }



    fun init(ctx: &mut TxContext){
        let admin = Admin {
            id: object::new(ctx),

        };

        let core_storage = CoreStorage{
            id: object::new(ctx), 
            fee_collector: tx_context::sender(ctx),
            fee: balance::zero<SUI>(),
            pixel_cost: 100000000, //0.1 SUI
        };

        transfer::transfer(admin, tx_context::sender(ctx));
        transfer::share_object(core_storage);
    }

    public entry fun initialize_canvas(
        _: &Admin,
        storage: &mut CanvasStorage,
        start: u64,
        end: u64,
        height: u64,
        width: u64,
        ctx: &mut TxContext,
    ){
        canvas::initialize_canvas(
            storage,
            start,
            end,
            height,
            width,
            ctx,
        );
    }

    public entry fun draw(
        canvas_storage: &mut CanvasStorage,
        core_storage: &mut CoreStorage,
        canvas_id: u64,
        x: u64,
        y: u64,
        r: u64,
        g: u64,
        b: u64,
        clock_obj: &Clock,
        coin_sui: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let cost = coin::split(&mut coin_sui, core_storage.pixel_cost, ctx);
        transfer::public_transfer(coin_sui, tx_context::sender(ctx));
        balance::join(&mut core_storage.fee, coin::into_balance(cost));

        canvas::draw(
            canvas_storage,
            canvas_id,
            x, y,
            r, g, b,
            clock_obj,
            ctx
        )
    }

    public entry fun set_pixel_cost(
        _: &Admin,
        core_storage: &mut CoreStorage,
        pixel_cost: u64,
    ){
        core_storage.pixel_cost = pixel_cost;
    }
}